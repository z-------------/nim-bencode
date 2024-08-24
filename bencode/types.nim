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
    bkStr = "string"
    bkInt = "integer"
    bkList = "list"
    bkDict = "dictionary"
  BencodeObj* = object
    case kind*: BencodeKind
    of bkStr:
      s*: string
    of bkInt:
      i*: int
    of bkList:
      l*: seq[BencodeObj]
    of bkDict:
      d*: OrderedTable[string, BencodeObj]
  BencodeFormat* = enum
    Normal
    Hexadecimal
    Decimal

# $ #

func toString*(a: BencodeObj; f = Normal): string

func toString(str: string; f = Normal): string =
  case f
  of Hexadecimal: str.map(c => "\\x" & ord(c).toHex(2)).join("")
  of Decimal: str.map(c => "\\d" & ord(c).`$`.align(4, '0')).join("")
  else: str

func toString(l: seq[BencodeObj]; f = Normal): string =
  "@[" & l.map(obj => obj.toString(f)).join(", ") & "]"

func toString(d: OrderedTable[string, BencodeObj]; f = Normal): string =
  "{ " & collect(newSeq, for k, v in d.pairs: k.toString(f) & ": " & v.toString(f)).join(", ") & " }"

func toString*(a: BencodeObj; f = Normal): string =
  case a.kind
  of bkStr: '"' & a.s.toString(f) & '"'
  of bkInt: $a.i
  of bkList: a.l.toString(f)
  of bkDict: a.d.toString(f)

func `$`*(a: BencodeObj): string =
  a.toString(Normal)

# equality #

func hash*(obj: BencodeObj): Hash =
  case obj.kind
  of bkStr: !$(hash(obj.s))
  of bkInt: !$(hash(obj.i))
  of bkList: !$(hash(obj.l))
  of bkDict:
    var h = default Hash
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

proc `name=`(procDef, name: NimNode) =
  procDef.expectKind nnkProcDef
  name.expectKind {nnkIdent, nnkSym}

  case procDef[0].kind
  of nnkPostfix:
    procDef[0][1] = name
  of nnkIdent:
    procDef[0] = name
  else:
    error("unexpected node kind", procDef[0])

macro alias(name, procDef: untyped): untyped =
  procDef.expectKind nnkProcDef
  name.expectKind {nnkIdent, nnkSym}

  let aliasProcDef = procDef.copy
  aliasProcDef.name = name
  newStmtList(procDef, aliasProcDef)

proc Bencode*(s: sink string): BencodeObj {.alias: be.} =
  BencodeObj(kind: bkStr, s: s)

proc Bencode*(i: int): BencodeObj {.alias: be.} =
  BencodeObj(kind: bkInt, i: i)

proc Bencode*(l: sink seq[BencodeObj]): BencodeObj {.alias: be.} =
  BencodeObj(kind: bkList, l: l)

proc Bencode*(l: sink openArray[BencodeObj]): BencodeObj {.alias: be.} =
  BencodeObj(kind: bkList, l: l.toSeq)

proc Bencode*(d: sink OrderedTable[string, BencodeObj]): BencodeObj {.alias: be.} =
  BencodeObj(kind: bkDict, d: d)

proc Bencode*(d: sink openArray[(string, BencodeObj)]): BencodeObj {.alias: be.} =
  Bencode(d.toOrderedTable)

func toBencodeObjImpl(value: NimNode): NimNode =
  # Adapted from std/json's `%*`: https://github.com/nim-lang/Nim/blob/0b44840299c15faa3b74cb82f48dcd56023f7d35/lib/pure/json.nim#L411
  case value.kind
  of nnkBracket: # array
    if value.len == 0:
      quote: BencodeObj(kind: bkList)
    else:
      var bracketNode = nnkBracket.newNimNode()
      for i in 0 ..< value.len:
        bracketNode.add(toBencodeObjImpl(value[i]))
      newCall(bindSym("Bencode", brOpen), bracketNode)
  of nnkTableConstr: # object
    if value.len == 0:
      quote: BencodeObj(kind: bkDict)
    else:
      var tableNode = nnkTableConstr.newNimNode()
      for i in 0 ..< value.len:
        value[i].expectKind nnkExprColonExpr
        tableNode.add nnkExprColonExpr.newTree(value[i][0], toBencodeObjImpl(value[i][1]))
      newCall(bindSym("Bencode", brOpen), tableNode)
  of nnkPar:
    if value.len == 1:
      toBencodeObjImpl(value[0])
    else:
      # what is this?
      newCall(bindSym("Bencode", brOpen), value)
  else:
    newCall(bindSym("Bencode", brOpen), value)

macro toBencodeObj*(value: untyped): BencodeObj =
  toBencodeObjImpl(value)

macro toBencode*(value: untyped): untyped {.deprecated: "use toBencodeObj instead".} =
  toBencodeObjImpl(value)
