import std/[
  streams,
  strformat,
  strutils,
  tables,
]
import ./types

export types

# encode #

proc bEncode*(obj: BencodeObj): string

proc encodeStr(s: string): string =
  $s.len & ':' & s

proc encodeInt(i: int): string =
  'i' & $i & 'e'

proc encodeList(l: seq[BencodeObj]): string =
  result = "l"
  for el in l:
    result &= bEncode(el)
  result &= "e"

proc encodeDict(d: OrderedTable[string, BencodeObj]): string =
  var d = d
  d.sort do (x, y: tuple[key: string; value: BencodeObj]) -> int:
    system.cmp(x.key, y.key)

  result = "d"
  for k, v in d.pairs():
    result &= encodeStr(k) & bEncode(v)

  result &= "e"

proc bEncode*(obj: BencodeObj): string =
  result = case obj.kind
    of bkStr:
      encodeStr(obj.s)
    of bkInt:
      encodeInt(obj.i)
    of bkList:
      encodeList(obj.l)
    of bkDict:
      encodeDict(obj.d)

# decode #

proc consume(s: Stream; c: char) =
  ## Check that the char at the current position is `c`, then consume it.
  if s.atEnd:
    raise (ref ValueError)(msg: &"expected '{c}', got end of input")
  let actual = s.readChar()
  if actual != c:
    raise (ref ValueError)(msg: &"expected '{c}', got {actual}")

proc parseHook(s: Stream; v: var string) =
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

proc parseHook(s: Stream; v: var int) =
  # i<ascii>e
  consume(s, 'i')
  var iStr = ""
  while not s.atEnd and s.peekChar() != 'e':
    iStr &= s.readChar()
  consume(s, 'e')
  v = parseInt(iStr)

proc parseHook[T](s: Stream; v: var seq[T]) =
  # l ... e
  v = newSeq[T]()
  consume(s, 'l')
  while not s.atEnd and s.peekChar() != 'e':
    var item: T
    parseHook(s, item)
    v.add(item)
  consume(s, 'e')

proc parseHook[T](s: Stream; v: var OrderedTable[string, T]) =
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

proc parseHook(s: Stream; v: var BencodeObj) =
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

proc bDecode*(s: Stream): BencodeObj =
  parseHook(s, result)

proc bDecode*(source: string): BencodeObj =
  bDecode(newStringStream(source))

proc bDecode*(f: File): BencodeObj =
  bDecode(newFileStream(f))
