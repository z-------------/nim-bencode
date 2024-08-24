import ./types
import std/[
  streams,
  strformat,
  strutils,
  tables,
]

export types

proc consume(s: Stream; c: char) =
  ## Check that the char at the current position is `c`, then consume it.
  if s.atEnd:
    raise (ref ValueError)(msg: &"expected '{c}', got end of input")
  let actual = s.readChar()
  if actual != c:
    raise (ref ValueError)(msg: &"expected '{c}', got {actual}")

proc parseHook*(s: Stream; v: var string) =
  # <length>:<contents>
  # get the length
  var lengthStr = ""
  while not s.atEnd and s.peekChar() != ':':
    lengthStr &= s.readChar()
  consume(s, ':')
  let length = parseInt(lengthStr)
  if length < 0:
    raise (ref ValueError)(msg: &"invalid string length: {length}")

  # read the string
  v =
    if length >= 0:
      s.readStr(length)
    else:
      ""
  if v.len != length:
    raise (ref ValueError)(msg: &"string too short: expected {length} characters, got {v.len} characters")

proc parseHook*(s: Stream; v: var int) =
  # i<ascii>e
  consume(s, 'i')
  var iStr = ""
  while not s.atEnd and s.peekChar() != 'e':
    iStr &= s.readChar()
  consume(s, 'e')
  v = parseInt(iStr)

proc parseHook*[T](s: Stream; v: var seq[T]) =
  # l ... e
  v = newSeq[T]()
  consume(s, 'l')
  while not s.atEnd and s.peekChar() != 'e':
    var item: T
    parseHook(s, item)
    v.add(item)
  consume(s, 'e')

type SomeTable[K, V] = Table[K, V] or OrderedTable[K, V]

proc parseHookTableImpl[T](s: Stream; v: var SomeTable[string, T]) =
  # d ... e
  var
    isReadingKey = true
    curKey = ""
  consume(s, 'd')
  while not s.atEnd and s.peekChar() != 'e':
    if isReadingKey:
      parseHook(s, curKey)
      isReadingKey = false
    else:
      var value: T
      parseHook(s, value)
      v[curKey] = value
      isReadingKey = true
  consume(s, 'e')

proc parseHook*[T](s: Stream; v: var OrderedTable[string, T]) =
  # TODO why is this needed?
  parseHookTableImpl(s, v)

proc parseHook*[T](s: Stream; v: var Table[string, T]) =
  parseHookTableImpl(s, v)

proc parseHook*(s: Stream; v: var BencodeObj) =
  assert not s.atEnd
  case s.peekChar()
    of 'i':
      v = BencodeObj(kind: bkInt)
      parseHook(s, v.i)
    of 'l':
      v = BencodeObj(kind: bkList)
      parseHook(s, v.l)
    of 'd':
      v = BencodeObj(kind: bkDict)
      parseHook(s, v.d)
    else:
      v = BencodeObj(kind: bkStr)
      parseHook(s, v.s)

import std/json

proc parseHook*(s: Stream; v: var JsonNode) =
  assert not s.atEnd
  case s.peekChar()
    of 'i':
      var value: int
      parseHook(s, value)
      v = newJInt(value)
    of 'l':
      var value: seq[JsonNode]
      parseHook(s, value)
      v = newJArray()
      v.elems = value
    of 'd':
      var value: OrderedTable[string, JsonNode]
      parseHook(s, value)
      v = newJObject()
      v.fields = value
    else:
      var value: string
      parseHook(s, value)
      v = newJString(value)

proc parseHook*[T: object](s: Stream; v: var T) =
  # d ... e
  # TODO Similar to the parseHook for OrderedTable. Unify or factor them somehow?
  var
    isReadingKey = true
    curKey = ""
  consume(s, 'd')
  while not s.atEnd and s.peekChar() != 'e':
    if isReadingKey:
      parseHook(s, curKey)
      isReadingKey = false
    else:
      for name, value in fieldPairs(v):
        if name == curKey:
          parseHook(s, value)
      isReadingKey = true
  consume(s, 'e')

proc parseHook*[T: ref object](s: Stream; v: var T) =
  v = T()
  parseHook(s, v[])

proc fromBencode*(t: typedesc; s: Stream): t =
  parseHook(s, result)

proc fromBencode*(t: typedesc; source: string): t =
  fromBencode(t, newStringStream(source))

proc fromBencode*(s: Stream; t: typedesc): t {.deprecated: "use fromBencode(typedesc, Stream) instead".} =
  ## Logically backwards overload to match jsony's interface.
  parseHook(s, result)

proc fromBencode*(source: string; t: typedesc): t {.deprecated: "use fromBencode(typedesc, string) instead".} =
  ## Logically backwards overload to match jsony's interface.
  fromBencode(t, newStringStream(source))

proc bDecode*(s: Stream): BencodeObj =
  parseHook(s, result)

proc bDecode*(source: string): BencodeObj =
  bDecode(newStringStream(source))

proc bDecode*(f: File): BencodeObj =
  bDecode(newFileStream(f))
