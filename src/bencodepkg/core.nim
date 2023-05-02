import std/[
  streams,
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

proc bDecode*(s: Stream): BencodeObj

proc decodeStr(s: Stream): BencodeObj =
  # <length>:<contents>
  # get the length
  var lengthStr = ""
  while not s.atEnd and s.peekChar() != ':':
    lengthStr &= s.readChar()
  discard s.readChar()  # advance past the ':'
  let length = parseInt(lengthStr)

  # read the string
  let str =
    if length >= 0:
      s.readStr(length)
    else:
      ""
  BencodeObj(kind: bkStr, s: str)

proc decodeInt(s: Stream): BencodeObj =
  # i<ascii>e
  var iStr = ""
  discard s.readChar()  # 'i'
  while not s.atEnd and s.peekChar() != 'e':
    iStr &= s.readChar()
  discard s.readChar()  # 'e'
  BencodeObj(kind: bkInt, i: parseInt(iStr))

proc decodeList(s: Stream): BencodeObj =
  # l ... e
  var l: seq[BencodeObj]
  discard s.readChar()  # advance past the 'l'
  while not s.atEnd and s.peekChar() != 'e':
    l.add(bDecode(s))
  discard s.readChar()  # 'e'
  BencodeObj(kind: bkList, l: l)

proc decodeDict(s: Stream): BencodeObj =
  # d ... e
  var
    d: OrderedTable[string, BencodeObj]
    isReadingKey = true
    curKey: string
  discard s.readChar()  # 'd'
  while not s.atEnd and s.peekChar() != 'e':
    if isReadingKey:
      let keyObj = bDecode(s)
      if keyObj.kind != bkStr:
        raise newException(ValueError, "invalid dictionary key: expected " & $bkStr & ", got " & $keyObj.kind)
      curKey = keyObj.s
      isReadingKey = false
    else:
      d[curKey] = bDecode(s)
      isReadingKey = true
  discard s.readChar()  # 'e'
  BencodeObj(kind: bkDict, d: d)

proc bDecode*(s: Stream): BencodeObj =
  assert not s.atEnd
  result = case s.peekChar()
    of 'i': decodeInt(s)
    of 'l': decodeList(s)
    of 'd': decodeDict(s)
    else: decodeStr(s)

proc bDecode*(source: string): BencodeObj =
  bDecode(newStringStream(source))

proc bDecode*(f: File): BencodeObj =
  bDecode(newFileStream(f))
