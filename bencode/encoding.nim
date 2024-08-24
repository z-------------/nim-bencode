import ./private/macros
import ./types
import std/[
  algorithm,
  sequtils,
  tables,
]

export types

type
  BencodeEncodeError* = object of BencodeError

proc dumpHook*(s: var string; v: string) =
  s &= $v.len & ':' & v

proc dumpHook*(s: var string; v: int) =
  s &= 'i' & $v & 'e'

proc dumpHook*[T](s: var string; v: openArray[T]) =
  s &= 'l'
  for el in v:
    dumpHook(s, el)
  s &= 'e'

template maybeDumpDictPair(s: var string; k, v: untyped) =
  # TODO skipHook for values
  when v is ref:
    if v != nil:
      dumpHook(s, k)
      dumpHook(s, v)
  else:
    dumpHook(s, k)
    dumpHook(s, v)

proc dumpHook*[T](s: var string; v: OrderedTable[string, T]) =
  var v = v
  v.sort do (x, y: tuple[key: string; value: T]) -> int:
    system.cmp(x.key, y.key)
  s &= 'd'
  for k, v in v.pairs():
    maybeDumpDictPair(s, k, v)
  s &= 'e'

proc dumpHook*[T](s: var string; v: Table[string, T]) =
  var pairs = v.pairs.toSeq
  pairs.sort do (a, b: (string, T)) -> int:
    system.cmp(a[0], b[0])
  s &= 'd'
  for (k, v) in pairs.items:
    maybeDumpDictPair(s, k, v)
  s &= 'e'

proc dumpHook*(s: var string; v: BencodeObj) =
  case v.kind
  of Str:
    dumpHook(s, v.s)
  of Int:
    dumpHook(s, v.i)
  of List:
    dumpHook(s, v.l)
  of Dict:
    dumpHook(s, v.d)

import std/json

proc dumpHook*[T: JsonNode](s: var string; v: T) =
  case v.kind
  of JString:
    dumpHook(s, v.getStr)
  of JInt:
    dumpHook(s, v.getInt)
  of JArray:
    dumpHook(s, v.getElems)
  of JObject:
    dumpHook(s, v.getFields)
  of JNull:
    raise (ref BencodeEncodeError)(msg: "cannot bencode a JSON null")
  of JFloat:
    when compiles(dumpHook(s, v.getFloat)):
      dumpHook(s, v.getFloat)
    else:
      raise (ref BencodeEncodeError)(msg: "cannot bencode a JSON float")
  of JBool:
    dumpHook(s, v.getBool.int)

proc dumpHook*[T: object](s: var string; v: T) =
  s &= 'd'
  sortedFieldPairs(v, name, value):
    maybeDumpDictPair(s, name, value)
  s &= 'e'

proc dumpHook*[T: ref object](s: var string; v: T) =
  if v == nil:
    raise (ref BencodeEncodeError)(msg: "cannot bencode a nil ref")
  dumpHook(s, v[])

proc toBencode*[T](v: T): string =
  ## Encode `v` as bencode.
  ##
  ## .. Note:: The macro that used to be called `toBencode` is now `toBencodeObj`.
  runnableExamples:
    import std/json

    type Record = object
      name: string
      data: BencodeObj
      json: JsonNode

    let record = Record(
      name: "Steve",
      data: be({
        "foo": be"bar",
        "baz": be(1),
      }),
      json: %*{"hello": "world"},
    )
    doAssert record.toBencode == "d4:datad3:bazi1e3:foo3:bare4:jsond5:hello5:worlde4:name5:Stevee"

  result = ""
  dumpHook(result, v)

proc bEncode*(obj: BencodeObj): string =
  ## Same as `obj.toBencode<#toBencode,T>`_.
  toBencode(obj)
