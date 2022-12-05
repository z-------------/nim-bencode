import std/[
  hashes,
  sequtils,
  strutils,
  sugar,
  tables,
]

type
  BencodeKind* = enum
    bkStr
    bkInt
    bkList
    bkDict
  BencodeObj* = object
    case kind*: BencodeKind
    of bkStr:
      s*: string
    of bkInt:
      i*: int
    of bkList:
      l*: seq[BencodeObj]
    of bkDict:
      d*: OrderedTable[BencodeObj, BencodeObj]

# equality #

proc hash*(obj: BencodeObj): Hash =
  case obj.kind
  of bkStr: !$(hash(obj.s))
  of bkInt: !$(hash(obj.i))
  of bkList: !$(hash(obj.l))
  of bkDict:
    var h: Hash
    for k, v in obj.d.pairs:
      h = hash(k) !& hash(v)
    !$(h)

proc `==`*(a, b: BencodeObj): bool =
  if a.kind != b.kind:
    result = false
  else:
    case a.kind
    of bkStr:
      result = a.s == b.s
    of bkInt:
      result = a.i == b.i
    of bkList:
      result = a.l == b.l
    of bkDict:
      if a.d.len != b.d.len:
        return false
      for key in a.d.keys:
        if not b.d.hasKey(key):
          return false
        if a.d[key] != b.d[key]:
          return false
      result = true

# constructors #

proc Bencode*(s: sink string): BencodeObj =
  BencodeObj(kind: bkStr, s: s)

proc Bencode*(i: int): BencodeObj =
  BencodeObj(kind: bkInt, i: i)

proc Bencode*(l: sink seq[BencodeObj]): BencodeObj =
  BencodeObj(kind: bkList, l: l)

proc Bencode*(d: sink OrderedTable[BencodeObj, BencodeObj]): BencodeObj =
  BencodeObj(kind: bkDict, d: d)

proc Bencode*(d: sink openArray[(BencodeObj, BencodeObj)]): BencodeObj =
  Bencode(d.toOrderedTable)

proc Bencode*(d: sink openArray[(string, BencodeObj)]): BencodeObj =
  var convertedDict: OrderedTable[BencodeObj, BencodeObj]
  for key, val in d.items:
    convertedDict[Bencode(key)] = val
  Bencode(convertedDict)

# $ #

proc toString*(a: BencodeObj; f = 'u'): string

proc toString(str: string; f = 'u'): string =
  case f
  of 'x': str.map(c => "\\x" & ord(c).toHex(2)).join("")
  of 'd': str.map(c => "\\d" & ord(c).`$`.align(4, '0')).join("")
  else: str

proc toString(l: seq[BencodeObj]; f = 'u'): string =
  "@[" & l.map(obj => obj.toString(f)).join(", ") & "]"

proc toString(d: OrderedTable[BencodeObj, BencodeObj]; f = 'u'): string =
  "{ " & collect(newSeq, for k, v in d.pairs: k.toString(f) & ": " & v.toString(f)).join(", ") & " }"

proc toString*(a: BencodeObj; f = 'u'): string =
  case a.kind
  of bkStr: '"' & a.s.toString(f) & '"'
  of bkInt: $a.i
  of bkList: a.l.toString(f)
  of bkDict: a.d.toString(f)

proc `$`*(a: BencodeObj): string =
  a.toString('u')
