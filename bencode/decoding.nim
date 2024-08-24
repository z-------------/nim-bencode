import ./private/streams
import ./types
import std/[
  parseutils,
  strformat,
  tables,
]
when NimMajor >= 2:
  import std/[
    assertions,
    syncio,
  ]

export types
export atEnd, readChar, peekChar, getPosition, readStr # why is this needed?

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

proc newBencodeDecodeError(s: var InputStream; kind: BencodeDecodeErrorKind; msg: string): ref BencodeDecodeError =
  newBencodeDecodeError(s.getPosition, kind, msg)

proc consume(s: var InputStream; c: char) =
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

proc parseHook*(s: var InputStream; v: var string) =
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
      try:
        s.readStr(length)
      except IOError as e:
        raise newBencodeDecodeError(s, UnexpectedEndOfInput, e.msg)
    else:
      ""

proc parseHook*(s: var InputStream; v: var int) =
  # i<ascii>e
  consume(s, 'i')
  var iStr = ""
  while not s.atEnd and s.peekChar() != 'e':
    iStr &= s.readChar()
  consume(s, 'e')
  v = parseInt(iStr, s.getPosition)

proc parseHook*[T](s: var InputStream; v: var seq[T]) =
  # l ... e
  v = newSeq[T]()
  consume(s, 'l')
  while not s.atEnd and s.peekChar() != 'e':
    var item = default T
    parseHook(s, item)
    v.add(item)
  consume(s, 'e')

proc parseHook*[T; C: static int](s: var InputStream; v: var array[C, T]) =
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

template parseHookDictImpl(s: var InputStream; body: untyped) =
  # d ... e
  var
    isReadingKey = true
    curKey {.inject.} = ""
  consume(s, 'd')
  while not s.atEnd and s.peekChar() != 'e':
    if isReadingKey:
      parseHook(s, curKey)
      isReadingKey = false
    else:
      body
      isReadingKey = true
  # TODO raise on incomplete pair
  consume(s, 'e')

type SomeTable[K, V] = Table[K, V] or OrderedTable[K, V]

proc parseHookTableImpl[T](s: var InputStream; v: var SomeTable[string, T]) =
  parseHookDictImpl(s):
    var value = default T
    parseHook(s, value)
    v[curKey] = value

proc parseHook*[T](s: var InputStream; v: var OrderedTable[string, T]) =
  # why is this needed?
  parseHookTableImpl(s, v)

proc parseHook*[T](s: var InputStream; v: var Table[string, T]) =
  parseHookTableImpl(s, v)

proc parseHook*(s: var InputStream; v: var BencodeObj) =
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

proc parseHook*(s: var InputStream; v: var JsonNode) =
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

proc parseHook*[T: object](s: var InputStream; v: var T) =
  parseHookDictImpl(s):
    for name, value in fieldPairs(v):
      if name == curKey:
        parseHook(s, value)

proc parseHook*[T: ref object](s: var InputStream; v: var T) =
  v = T()
  parseHook(s, v[])

proc fromBencode(t: typedesc; s: var InputStream): t =
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

  var s = toInputStream source
  fromBencode(t, s)

import std/streams

proc fromBencode*(t: typedesc; s: Stream): t =
  ## Decode bencoded data from `s` into a value of type `t`.
  var s = toInputStream s
  fromBencode(t, s)

proc fromBencode*(t: typedesc; f: File): t =
  ## Decode bencoded data from `f` into a value of type `t`.
  fromBencode(t, newFileStream(f))

proc fromBencode*(source: string; t: typedesc): t {.deprecated: "use fromBencode(typedesc, string) instead".} =
  ## Logically backwards overload to match jsony's interface.
  fromBencode(t, source)

proc bDecode*(s: Stream): BencodeObj =
  ## Same as `BencodeObj.fromBencode(s)`.
  fromBencode(BencodeObj, s)

proc bDecode*(source: string): BencodeObj =
  ## Same as `BencodeObj.fromBencode(source)`.
  fromBencode(BencodeObj, source)

proc bDecode*(f: File): BencodeObj =
  ## Same as `BencodeObj.fromBencode(f)`.
  fromBencode(BencodeObj, f)
