import tables
import strutils
import streams
import ./types

export types

# encode #

proc encode*(obj: BencodeObj): string

proc encodeStr(s: string): string =
  $s.len & ':' & s

proc encodeInt(i: int): string =
  'i' & $i & 'e'
  
proc encodeList(l: seq[BencodeObj]): string =
  result = "l"
  for el in l:
    result &= encode(el)
  result &= "e"

proc encodeDict(d: OrderedTable[BencodeObj, BencodeObj]): string =
  result = "d"
  for k, v in d.pairs():
    assert k.kind == bkStr
    result &= encode(k) & encode(v)

  result &= "e"

proc encode*(obj: BencodeObj): string =
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

proc decode*(s: Stream): BencodeObj

proc decodeStr(s: Stream): BencodeObj =
  # <length>:<contents>
  # get the length
  var lengthStr = ""
  while s.peekChar() != ':':
    lengthStr &= s.readChar()
  discard s.readChar()  # advance past the ':'
  let length = parseInt(lengthStr)

  # read the string
  let str = s.readStr(length)
  Bencode(str)

proc decodeInt(s: Stream): BencodeObj =
  # i<ascii>e
  var iStr = ""
  discard s.readChar()  # 'i'
  while s.peekChar() != 'e':
    iStr &= s.readChar()
  discard s.readChar()  # 'e'
  let i = parseInt(iStr)
  Bencode(i)
  
proc decodeList(s: Stream): BencodeObj =
  # l ... e
  var l = newSeq[BencodeObj]()
  discard s.readChar()  # advance past the 'l'
  while not s.atEnd and s.peekChar() != 'e':
    let obj = decode(s)
    l.add(obj)
  discard s.readChar()  # 'e'
  Bencode(l)

proc decodeDict(s: Stream): BencodeObj =
  # d ... e
  var
    d = initOrderedTable[BencodeObj, BencodeObj]()
    isReadingKey = true
    curKey: BencodeObj
  discard s.readChar()  # 'd'
  while not s.atEnd and s.peekChar() != 'e':
    let obj = decode(s)
    if isReadingKey:
      curKey = obj
      isReadingKey = false
    else:
      d[curKey] = obj
      isReadingKey = true
  discard s.readChar()  # 'e'
  Bencode(d)

proc decode*(s: Stream): BencodeObj =
  assert not s.atEnd
  result = case s.peekChar()
    of 'i': decodeInt(s)
    of 'l': decodeList(s)
    of 'd': decodeDict(s)
    else: decodeStr(s)

proc decode*(source: string): BencodeObj =
  decode(newStringStream(source))

proc decode*(f: File): BencodeObj =
  decode(newFileStream(f))
