import ./types
import std/[
  assertions,
  parseutils,
  streams,
  strformat,
  syncio,
  tables,
]

export types

type
  BencodeDecodeErrorKind* = enum
    SyntaxError
    UnexpectedEndOfInput
    WrongLength
    InvalidValue
  BencodeDecodeError* = object of ValueError
    kind* {.requiresInit.}: BencodeDecodeErrorKind
    pos* {.requiresInit.}: int

proc newBencodeDecodeError(pos: int; kind: BencodeDecodeErrorKind; msg: string): ref BencodeDecodeError =
  (ref BencodeDecodeError)(msg: msg, kind: kind, pos: pos)

proc newBencodeDecodeError(s: Stream; kind: BencodeDecodeErrorKind; msg: string): ref BencodeDecodeError =
  newBencodeDecodeError(s.getPosition, kind, msg)

proc consume(s: Stream; c: char) =
  ## Check that the char at the current position is `c`, then consume it.
  if s.atEnd:
    raise newBencodeDecodeError(s, UnexpectedEndOfInput, &"expected '{c}', got end of input")
  let actual = s.readChar()
  if actual != c:
    raise newBencodeDecodeError(s, SyntaxError, &"expected '{c}', got {actual}")

proc parseInt(str: string; pos: int): int =
  result = 0 # parseutils.parseInt's second parameter really should be marked `out`
  if parseutils.parseInt(str, result) != str.len:
    raise newBencodeDecodeError(pos, SyntaxError, &"invalid integer: {str}")

proc parseHook*(s: Stream; v: var string) =
  # <length>:<contents>
  # get the length
  var lengthStr = ""
  while not s.atEnd and s.peekChar() != ':':
    lengthStr &= s.readChar()
  consume(s, ':')
  let length = parseInt(lengthStr, s.getPosition)
  if length < 0:
    raise newBencodeDecodeError(s, InvalidValue, &"invalid string length: {length}")

  # read the string
  v =
    if length >= 0:
      s.readStr(length)
    else:
      ""
  if v.len != length:
    raise newBencodeDecodeError(s, WrongLength, &"string too short: expected {length} characters, got {v.len} characters")

proc parseHook*(s: Stream; v: var int) =
  # i<ascii>e
  consume(s, 'i')
  var iStr = ""
  while not s.atEnd and s.peekChar() != 'e':
    iStr &= s.readChar()
  consume(s, 'e')
  v = parseInt(iStr, s.getPosition)

proc parseHook*[T](s: Stream; v: var seq[T]) =
  # l ... e
  v = newSeq[T]()
  consume(s, 'l')
  while not s.atEnd and s.peekChar() != 'e':
    var item = default T
    parseHook(s, item)
    v.add(item)
  consume(s, 'e')

proc parseHook*[T; C: static int](s: Stream; v: var array[C, T]) =
  # l ... e
  v = default array[C, T]
  consume(s, 'l')
  var i = 0
  while not s.atEnd and s.peekChar() != 'e':
    if i >= C:
      raise newBencodeDecodeError(s, WrongLength, &"list too long: expected {C} items, got at least {i + 1} items")
    var item = default T
    parseHook(s, item)
    v[i] = item
    inc i
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
      var value = default T
      parseHook(s, value)
      v[curKey] = value
      isReadingKey = true
  # TODO raise on incomplete pair
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
      v = BencodeObj(kind: Int)
      parseHook(s, v.i)
    of 'l':
      v = BencodeObj(kind: List)
      parseHook(s, v.l)
    of 'd':
      v = BencodeObj(kind: Dict)
      parseHook(s, v.d)
    else:
      v = BencodeObj(kind: Str)
      parseHook(s, v.s)

import std/json

proc parseHook*(s: Stream; v: var JsonNode) =
  assert not s.atEnd
  case s.peekChar()
    of 'i':
      var value = default int
      parseHook(s, value)
      v = newJInt(value)
    of 'l':
      var value = default seq[JsonNode]
      parseHook(s, value)
      v = newJArray()
      v.elems = value
    of 'd':
      var value = default OrderedTable[string, JsonNode]
      parseHook(s, value)
      v = newJObject()
      v.fields = value
    else:
      var value = default string
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
  ## Decode bencoded data from `s` into a value of type `t`.
  result = default t
  parseHook(s, result)

proc fromBencode*(t: typedesc; source: string): t =
  ## Decode bencoded data from `source` into a value of type `t`.
  runnableExamples:
    type Foo = object
      a: int
      b: string
      c: BencodeObj

    let data = "d1:b11:hello world1:ai42e1:c16:embedded bencodee"
    doAssert Foo.fromBencode(data) == Foo(
      a: 42,
      b: "hello world",
      c: Bencode("embedded bencode"),
    )

  fromBencode(t, newStringStream(source))

proc fromBencode*(s: Stream; t: typedesc): t {.deprecated: "use fromBencode(typedesc, Stream) instead".} =
  ## Logically backwards overload to match jsony's interface.
  parseHook(s, result)

proc fromBencode*(source: string; t: typedesc): t {.deprecated: "use fromBencode(typedesc, string) instead".} =
  ## Logically backwards overload to match jsony's interface.
  fromBencode(t, newStringStream(source))

proc bDecode*(s: Stream): BencodeObj =
  ## Same as `BencodeObj.fromBencode(s)`.
  fromBencode(BencodeObj, s)

proc bDecode*(source: string): BencodeObj =
  ## Same as `BencodeObj.fromBencode(source)`.
  fromBencode(BencodeObj, source)

proc bDecode*(f: File): BencodeObj =
  fromBencode(BencodeObj, newFileStream(f))
