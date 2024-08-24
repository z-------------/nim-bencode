import ./types
import std/[
  tables,
]

export types

proc dumpHook*(s: var string; v: string) =
  s &= $v.len & ':' & v

proc dumpHook*(s: var string; v: int) =
  s &= 'i' & $v & 'e'

proc dumpHook*[T](s: var string; v: openArray[T]) =
  s &= "l"
  for el in v:
    dumpHook(s, el)
  s &= "e"

proc dumpHook*[T](s: var string; v: OrderedTable[string, T]) =
  var v = v
  v.sort do (x, y: tuple[key: string; value: T]) -> int:
    system.cmp(x.key, y.key)
  s &= "d"
  for k, v in v.pairs():
    dumpHook(s, k)
    dumpHook(s, v)
  s &= "e"

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

proc bEncode*(obj: BencodeObj): string =
  result = ""
  dumpHook(result, obj)
