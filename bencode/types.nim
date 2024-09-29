import ./private/macros
import std/[
  enumerate,
  hashes,
  macros,
  sequtils,
  strutils,
  tables,
]

template name*(name: string) {.pragma.}

type
  BencodeKind* = enum
    Str = "string"
    Int = "integer"
    List = "list"
    Dict = "dictionary"
  BencodeObj* = object
    case kind*: BencodeKind
    of Str:
      s*: string
    of Int:
      i*: int
    of List:
      l*: seq[BencodeObj]
    of Dict:
      d*: OrderedTable[string, BencodeObj]
  BencodeFormat* = enum
    Normal
    Hexadecimal
    Decimal
  BencodeError* = object of ValueError

removeDeprecated:
  const
    bkStr* {.deprecated: "use Str instead".} = BencodeKind.Str
    bkInt* {.deprecated: "use Int instead".} = BencodeKind.Int
    bkList* {.deprecated: "use List instead".} = BencodeKind.List
    bkDict* {.deprecated: "use Dict instead".} = BencodeKind.Dict

# $ #

func toString*(a: BencodeObj; f = Normal): string {.raises: [].}

func toString(str: string; f = Normal): string =
  result = ""
  case f
  of Hexadecimal:
    for c in str:
      result.add "\\x" & c.ord.toHex(2)
  of Decimal:
    for c in str:
      result.add "\\d" & ($c.ord).align(4, '0')
  else:
    result = str

func toString(l: seq[BencodeObj]; f = Normal): string =
  result = "@["
  for i, obj in l.pairs:
    if i != 0:
      result &= ", "
    result &= obj.toString(f)
  result &= "]"

func toString(d: OrderedTable[string, BencodeObj]; f = Normal): string =
  result = "{ "
  for i, (k, v) in enumerate(d.pairs):
    if i != 0:
      result &= ", "
    result &= k.toString(f)
    result &= ": "
    result &= v.toString(f)
  result &= " }"

func toString*(a: BencodeObj; f = Normal): string =
  case a.kind
  of Str: '"' & a.s.toString(f) & '"'
  of Int: $a.i
  of List: a.l.toString(f)
  of Dict: a.d.toString(f)

func `$`*(a: BencodeObj): string {.raises: [].} =
  a.toString(Normal)

# equality #

func hash*(obj: BencodeObj): Hash =
  case obj.kind
  of Str: !$(hash(obj.s))
  of Int: !$(hash(obj.i))
  of List: !$(hash(obj.l))
  of Dict:
    var h = default Hash
    for k, v in obj.d.pairs:
      h = hash(k) !& hash(v)
    !$(h)

func `==`*(a, b: BencodeObj): bool =
  if a.kind != b.kind:
    false
  else:
    case a.kind
    of Str:
      a.s == b.s
    of Int:
      a.i == b.i
    of List:
      a.l == b.l
    of Dict:
      if a.d.len != b.d.len:
        return false
      for key in a.d.keys:
        if not b.d.hasKey(key):
          return false
        if a.d[key] != b.d[key]:
          return false
      true

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
  BencodeObj(kind: Str, s: s)

proc Bencode*(i: int): BencodeObj {.alias: be.} =
  BencodeObj(kind: Int, i: i)

proc Bencode*(l: sink seq[BencodeObj]): BencodeObj {.alias: be.} =
  BencodeObj(kind: List, l: l)

proc Bencode*(l: sink openArray[BencodeObj]): BencodeObj {.alias: be.} =
  BencodeObj(kind: List, l: l.toSeq)

proc Bencode*(d: sink OrderedTable[string, BencodeObj]): BencodeObj {.alias: be.} =
  BencodeObj(kind: Dict, d: d)

proc Bencode*(d: sink openArray[(string, BencodeObj)]): BencodeObj {.alias: be.} =
  Bencode(d.toOrderedTable)

func toBencodeObjImpl(value: NimNode): NimNode =
  # Adapted from std/json's `%*`: https://github.com/nim-lang/Nim/blob/0b44840299c15faa3b74cb82f48dcd56023f7d35/lib/pure/json.nim#L411
  case value.kind
  of nnkBracket: # array
    if value.len == 0:
      quote: BencodeObj(kind: List)
    else:
      var bracketNode = nnkBracket.newNimNode()
      for i in 0 ..< value.len:
        bracketNode.add(toBencodeObjImpl(value[i]))
      newCall(bindSym("Bencode", brOpen), bracketNode)
  of nnkTableConstr: # object
    if value.len == 0:
      quote: BencodeObj(kind: Dict)
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
  ## .. Note:: Consider instead encoding directly from an object using `toBencode<encoding.html#toBencode,T>`_.
  toBencodeObjImpl(value)
