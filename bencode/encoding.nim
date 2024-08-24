import ./types
import std/[
  tables,
]

export types

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
