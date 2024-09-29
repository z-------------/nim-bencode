import ./utils
import pkg/bencode
import std/[
  streams,
  tables,
  unittest,
]

test "basic encode/decode":
  let
    myList = @[Bencode(1), Bencode("hi")]
    myDict =
      {
        "name": Bencode("dmdm"),
        "lang": Bencode("nim"),
        "age": Bencode(50),
        "alist": Bencode(myList),
      }
    testPairs =
      {
        Bencode("hello"): "5:hello",
        Bencode("yes"): "3:yes",
        Bencode(55): "i55e",
        Bencode(12345): "i12345e",
        Bencode(myList): "li1e2:hie",
        Bencode(myDict): "d3:agei50e5:alistli1e2:hie4:lang3:nim4:name4:dmdme",
      }.toOrderedTable

  for k, v in testPairs.pairs:
    check bEncode(k) == v
    check bDecode(v) == k

test "to/from (ref) object":
  type
    Record = object
      name: string
      lang {.name: "the language".}: string
      age: int
      alist: seq[BencodeObj]
      blist: seq[int]
      mydict: OrderedTable[string, string]
      myarray: array[2, string]
      notInBencode: string

  let expectedRecord = Record(
    name: "dmdm",
    lang: "nim",
    age: 50,
    alist: @[Bencode(1), Bencode("hi")],
    blist: @[100, 200],
    mydict: {"foo": "bar"}.toOrderedTable,
    myarray: ["hello", "world"],
    notInBencode: "",
  )

  # decode
  const data = "d3:agei50e9:extra keyi123e7:myarrayl5:hello5:worlde5:alistli1e2:hie12:the language3:nim4:name4:dmdm5:blistli100ei200ee6:mydictd3:foo3:baree"
  checkDecode(Record, data, expectedRecord)
  let refRecord = (ref Record).fromBencode(data)
  check refRecord != nil
  check refRecord[] == expectedRecord
  {.push warning[Deprecated]:off.}
  check data.fromBencode(Record) == expectedRecord
  {.pop.}

  # encode
  const dataOut = "d3:agei50e5:alistli1e2:hie5:blistli100ei200ee12:the language3:nim7:myarrayl5:hello5:worlde6:mydictd3:foo3:bare4:name4:dmdm12:notInBencode0:e"
  check expectedRecord.toBencode == dataOut
  check refRecord.toBencode == dataOut

test "to/from various table types":
  const data = "d3:agei50e5:alistli1e2:hie4:lang3:nim4:name4:dmdme"
  let expectedTablePairs = {
    "age": Bencode(50),
    "alist": Bencode(@[Bencode(1), Bencode("hi")]),
    "lang": Bencode("nim"),
    "name": Bencode("dmdm"),
  }
  check OrderedTable[string, BencodeObj].fromBencode(data) == expectedTablePairs.toOrderedTable
  check Table[string, BencodeObj].fromBencode(data) == expectedTablePairs.toTable
  check expectedTablePairs.toOrderedTable.toBencode == data
  check expectedTablePairs.toTable.toBencode == data

import std/json

test "to JsonNode":
  const data = "d3:agei50e5:alistli1e2:hie4:lang3:nim4:name4:dmdme"
  let expected = %*{
    "age": 50,
    "alist": [1, "hi"],
    "lang": "nim",
    "name": "dmdm",
  }
  check JsonNode.fromBencode(data) == expected

test "to/from array":
  let exception =
    expect BencodeDecodeError:
      discard array[2, string].fromBencode("l5:hello5:world2:!!ee")
  check exception.kind == WrongLength
  check exception.msg == "list too long: expected 2 items, got at least 3 items"

  check array[2, string].fromBencode("l5:hello5:worlde") == ["hello", "world"]
  check ["hello", "world"].toBencode == "l5:hello5:worlde"

test "nil ref objects":
  type
    Foo = object
      s: string
    Bar = object
      e: int
      f: ref Foo
      g: string

  let bar = Bar(e: 321, f: nil, g: "hi")
  const expected = "d1:ei321e1:g2:hie"
  let actual = bar.toBencode
  check actual == expected
  check Bar.fromBencode(actual) == bar
