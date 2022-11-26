import std/[
  strutils,
  tables,
]
import pkg/faststreams/inputs
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

proc encodeDict(d: OrderedTable[BencodeObj, BencodeObj]): string =
  result = "d"
  for k, v in d.pairs():
    assert k.kind == bkStr
    result &= bEncode(k) & bEncode(v)

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

template tryAdvance(s: InputStream) =
  if s.readable:
    s.advance

proc readStrInto(s: InputStream; outStr: var string; len: int) =
  let bytesRead = s.readIntoEx(outStr.toOpenArrayByte(0, len - 1))
  outStr.setLen(bytesRead)

proc bDecode*(s: InputStream): BencodeObj

proc decodeStr(s: InputStream): BencodeObj =
  # <length>:<contents>
  # get the length
  var lengthStr = ""
  while s.readable and s.peek.char != ':':
    lengthStr &= s.read.char
  s.tryAdvance # advance past the ':'
  let length = parseInt(lengthStr)

  # read the string
  if length > 0:
    result = BencodeObj(kind: bkStr, s: newString(length))
    s.readStrInto(result.s, length)
  else:
    result = BencodeObj(kind: bkStr, s: "")

proc decodeInt(s: InputStream): BencodeObj =
  # i<ascii>e
  var iStr = ""
  s.tryAdvance # 'i'
  while s.readable and s.peek.char != 'e':
    iStr &= s.read.char
  s.tryAdvance # 'e'
  BencodeObj(kind: bkInt, i: parseInt(iStr))

proc decodeList(s: InputStream): BencodeObj =
  # l ... e
  var l: seq[BencodeObj]
  s.tryAdvance # advance past the 'l'
  while s.readable and s.peek.char != 'e':
    l.add(bDecode(s))
  s.tryAdvance # 'e'
  BencodeObj(kind: bkList, l: l)

proc decodeDict(s: InputStream): BencodeObj =
  # d ... e
  var
    d: OrderedTable[BencodeObj, BencodeObj]
    isReadingKey = true
    curKey: BencodeObj
  s.tryAdvance # 'd'
  while s.readable and s.peek.char != 'e':
    if isReadingKey:
      curKey = bDecode(s)
      isReadingKey = false
    else:
      d[curKey] = bDecode(s)
      isReadingKey = true
  s.tryAdvance # 'e'
  BencodeObj(kind: bkDict, d: d)

proc bDecode*(s: InputStream): BencodeObj =
  assert s.readable
  result = case s.peek.char
    of 'i': decodeInt(s)
    of 'l': decodeList(s)
    of 'd': decodeDict(s)
    else: decodeStr(s)

proc bDecode*(source: string): BencodeObj =
  bDecode(unsafeMemoryInput(source))

proc bDecode*(f: File): BencodeObj =
  bDecode(fileInput(f))

# helpers #

func `[]`*(d: OrderedTable[BencodeObj, BencodeObj]; key: string): BencodeObj =
  d[Bencode(key)]

func `[]=`*(d: var OrderedTable[BencodeObj, BencodeObj]; key: string; value: sink BencodeObj) =
  d[Bencode(key)] = value
