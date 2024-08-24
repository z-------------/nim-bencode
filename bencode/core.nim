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

proc decode(s: Stream): BencodeObj

proc decodeStr(s: Stream): BencodeObj =
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
  let str =
    if length >= 0:
      s.readStr(length)
    else:
      ""
  if str.len != length:
    raise (ref ValueError)(msg: &"string too short: expected {length} characters, got {str.len} characters")
  BencodeObj(kind: bkStr, s: str)

proc decodeInt(s: Stream): BencodeObj =
  # i<ascii>e
  consume(s, 'i')
  var iStr = ""
  while not s.atEnd and s.peekChar() != 'e':
    iStr &= s.readChar()
  consume(s, 'e')
  BencodeObj(kind: bkInt, i: parseInt(iStr))

proc decodeList(s: Stream): BencodeObj =
  # l ... e
  var l = newSeq[BencodeObj]()
  consume(s, 'l')
  while not s.atEnd and s.peekChar() != 'e':
    l.add(decode(s))
  consume(s, 'e')
  BencodeObj(kind: bkList, l: l)

proc decodeDict(s: Stream): BencodeObj =
  # d ... e
  var
    d = initOrderedTable[string, BencodeObj]()
    isReadingKey = true
    curKey = ""
  consume(s, 'd')
  while not s.atEnd and s.peekChar() != 'e':
    if isReadingKey:
      let keyObj = decode(s)
      if keyObj.kind != bkStr:
        raise newException(ValueError, &"invalid dictionary key: expected {bkStr}, got {keyObj.kind}")
      curKey = keyObj.s
      isReadingKey = false
    else:
      d[curKey] = decode(s)
      isReadingKey = true
  consume(s, 'e')
  BencodeObj(kind: bkDict, d: d)

proc decode(s: Stream): BencodeObj =
  assert not s.atEnd
  result = case s.peekChar()
    of 'i': decodeInt(s)
    of 'l': decodeList(s)
    of 'd': decodeDict(s)
    else: decodeStr(s)

proc bDecode*(s: Stream): BencodeObj =
  decode(s)

proc bDecode*(source: string): BencodeObj =
  decode(newStringStream(source))

proc bDecode*(f: File): BencodeObj =
  decode(newFileStream(f))
