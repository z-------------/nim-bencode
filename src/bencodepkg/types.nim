import std/[
  hashes,
  macros,
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

# $ #

func toString*(a: BencodeObj; f = 'u'): string

func toString(str: string; f = 'u'): string =
  case f
  of 'x': str.map(c => "\\x" & ord(c).toHex(2)).join("")
  of 'd': str.map(c => "\\d" & ord(c).`$`.align(4, '0')).join("")
  else: str

func toString(l: seq[BencodeObj]; f = 'u'): string =
  "@[" & l.map(obj => obj.toString(f)).join(", ") & "]"

func toString(d: OrderedTable[BencodeObj, BencodeObj]; f = 'u'): string =
  "{ " & collect(newSeq, for k, v in d.pairs: k.toString(f) & ": " & v.toString(f)).join(", ") & " }"

func toString*(a: BencodeObj; f = 'u'): string =
  case a.kind
  of bkStr: '"' & a.s.toString(f) & '"'
  of bkInt: $a.i
  of bkList: a.l.toString(f)
  of bkDict: a.d.toString(f)

func `$`*(a: BencodeObj): string =
  a.toString('u')

# equality #

func hash*(obj: BencodeObj): Hash =
  case obj.kind
  of bkStr: !$(hash(obj.s))
  of bkInt: !$(hash(obj.i))
  of bkList: !$(hash(obj.l))
  of bkDict:
    var h: Hash
    for k, v in obj.d.pairs:
      h = hash(k) !& hash(v)
    !$(h)

func `==`*(a, b: BencodeObj): bool =
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

proc Bencode*(l: sink openArray[BencodeObj]): BencodeObj =
  BencodeObj(kind: bkList, l: l.toSeq)

proc Bencode*(d: sink OrderedTable[BencodeObj, BencodeObj]): BencodeObj =
  BencodeObj(kind: bkDict, d: d)

proc Bencode*(d: sink openArray[(BencodeObj, BencodeObj)]): BencodeObj =
  Bencode(d.toOrderedTable)

proc Bencode*(d: sink openArray[(string, BencodeObj)]): BencodeObj =
  var convertedDict: OrderedTable[BencodeObj, BencodeObj]
  for key, val in d.items:
    convertedDict[Bencode(key)] = val
  Bencode(convertedDict)

func toBencodeImpl(value: NimNode): NimNode =
  # Adapted from std/json's `%*`: https://github.com/nim-lang/Nim/blob/0b44840299c15faa3b74cb82f48dcd56023f7d35/lib/pure/json.nim#L411
  case value.kind
  of nnkBracket: # array
    if value.len == 0:
      quote: BencodeObj(kind: bkList)
    else:
      var bracketNode = nnkBracket.newNimNode()
      for i in 0 ..< value.len:
        bracketNode.add(toBencodeImpl(value[i]))
      newCall(bindSym("Bencode", brOpen), bracketNode)
  of nnkTableConstr: # object
    if value.len == 0:
      quote: BencodeObj(kind: bkDict)
    else:
      var tableNode = nnkTableConstr.newNimNode()
      for i in 0 ..< value.len:
        value[i].expectKind nnkExprColonExpr
        tableNode.add nnkExprColonExpr.newTree(toBencodeImpl(value[i][0]), toBencodeImpl(value[i][1]))
      newCall(bindSym("Bencode", brOpen), tableNode)
  of nnkPar:
    if value.len == 1:
      toBencodeImpl(value[0])
    else:
      # what is this?
      newCall(bindSym("Bencode", brOpen), value)
  else:
    newCall(bindSym("Bencode", brOpen), value)

macro toBencode*(value: untyped): untyped =
  toBencodeImpl(value)

template be*(strVal: string): BencodeObj =
  BencodeObj(kind: bkStr, s: strVal)

template be*(intVal: int): BencodeObj =
  BencodeObj(kind: bkInt, i: intVal)

template be*(listVal: seq[BencodeObj]): BencodeObj =
  BencodeObj(kind: bkList, l: listVal)

template be*(dictVal: OrderedTable[BencodeObj, BencodeObj]): BencodeObj =
  BencodeObj(kind: bkDict, d: dictVal)

template be*(dictVal: openArray[(BencodeObj, BencodeObj)]): BencodeObj =
  mixin toOrderedTable
  BencodeObj(kind: bkDict, d: dictVal.toOrderedTable)

template be*(dictVal: openArray[(string, BencodeObj)]): BencodeObj =
  Bencode(dictVal)

