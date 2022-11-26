import std/[
  json,
  sequtils,
  sugar,
  tables,
]
import ./core

proc asJFieldName(obj: BencodeObj): string =
  case obj.kind
  of bkStr: obj.s
  of bkInt: $obj.i
  else: $obj

# to #

proc newJArray(elems: seq[JsonNode]): JsonNode =
  result = newJArray()
  result.elems = elems

proc newJObject(fields: OrderedTable[string, JsonNode]): JsonNode =
  result = newJObject()
  result.fields = fields

proc toJson*(obj: BencodeObj): JsonNode =
  case obj.kind
  of bkStr:
    newJString(obj.s)
  of bkInt:
    newJInt(obj.i)
  of bkList:
    newJArray(
      collect(newSeq, for x in obj.l: x.toJson)
    )
  of bkDict:
    newJObject(
      collect(initOrderedTable, for k, v in obj.d.pairs:
        {k.asJFieldName: v.toJson}
      )
    )

# from #

proc fromJson*(j: JsonNode): BencodeObj =
  case j.kind
  of JNull:
    when defined(bencodeJsonStrict):
      raise newException(ValueError, "Cannot convert JSON null to Bencode")
    Bencode("")
  of JBool:
    Bencode(j.getBool.int)
  of JInt:
    Bencode(j.getInt)
  of JFloat:
    when defined(bencodeJsonStrict):
      raise newException(ValueError, "Cannot convert JSON float to Bencode")
    Bencode(j.getFloat.int)
  of JString:
    Bencode(j.getStr)
  of JObject:
    Bencode(
      collect(initOrderedTable, for k, v in j.getFields.pairs:
        {Bencode(k): v.fromJson}
      )
    )
  of JArray:
    Bencode(j.getElems.map(fromJson))
