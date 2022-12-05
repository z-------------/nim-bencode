import bencode
import std/unittest
import std/[
  json,
  tables,
]

test "basic encode/decode":
  let
    myList = @[Bencode(1), Bencode("hi")]
    myDict =
      {
        Bencode("name"): Bencode("dmdm"),
        Bencode("lang"): Bencode("nim"),
        Bencode("age"): Bencode(50),
        Bencode("alist"): Bencode(myList),
      }
    testPairs =
      {
        Bencode("hello"): "5:hello",
        Bencode("yes"): "3:yes",
        Bencode(55): "i55e",
        Bencode(12345): "i12345e",
        Bencode(myList): "li1e2:hie",
        Bencode(myDict): "d4:name4:dmdm4:lang3:nim3:agei50e5:alistli1e2:hiee",
      }.toOrderedTable

  for k, v in testPairs.pairs:
    check bEncode(k) == v
    check bDecode(v) == k

test "conversion to json":
  let
    expected = parseJson("""
    {
      "foo": 69,
      "bar": [
        {
          "baz": 420,
          "qux": 6969,
          "6969": "qux"
        }
      ]
    }
    """)
    actual = Bencode({
      Bencode("foo"): Bencode(69),
      Bencode("bar"): Bencode(@[
        Bencode({
          Bencode("baz"): Bencode(420),
          Bencode("qux"): Bencode(6969),
          Bencode(6969): Bencode("qux"),
        }),
      ]),
    }).toJson

  check actual == expected

test "conversion from json":
  let
    expected = Bencode({
      Bencode("foo"): Bencode(69),
      Bencode("bar"): Bencode(@[
        Bencode({
          Bencode("baz"): Bencode(420),
          Bencode("qux"): Bencode(6969),
        }),
        Bencode(3),  # float truncation
      ]),
    })
    actual = parseJson("""
    {
      "foo": 69,
      "bar": [
        {
          "baz": 420,
          "qux": 6969
        },
        3.14159
      ]
    }
    """).fromJson

  check actual == expected

test "readme example":
  let
    data = Bencode({
      Bencode("interval"): Bencode(1800),
      Bencode("min interval"): Bencode(900),
      Bencode("peers"): Bencode("\x0a\x0a\x0a\x05\x00\x80"),
      Bencode("complete"): Bencode(20),
      Bencode("incomplete"): Bencode(0),
    })
    bencodedData = bEncode(data)

  check bencodedData == "d8:intervali1800e12:min intervali900e5:peers6:\x0a\x0a\x0a\x05\x00\x808:completei20e10:incompletei0ee"
  check bDecode(bencodedData) == data

test "dictionary access by string key":
  var b = Bencode({
    "interval": Bencode(1800),
    "complete": Bencode(20),
  })
  check b.d["interval"] == Bencode(1800)
  b.d["complete"] = Bencode(30)
  check b.d["complete"] == Bencode(30)

test "execution terminates for invalid bencode input":
  const data = "d4:name4:dmdm4:lang3:nim3:agei50e5:alistli1e2:hiee"
  for i in 0 .. data.high:
    if i in {0, 30, 31, 35..40}:
      # input is valid even if we remove these indexes
      continue
    let invalidData = data[0 .. i - 1] & data[i + 1 .. ^1]
    try:
      discard bDecode(invalidData)
    except ValueError:
      discard

test "string too short":
  const data = "10:hello"
  check bDecode(data) == Bencode("hello")

test "invalid string length":
  const data = "-5:hello"
  check bDecode(data) == Bencode("")

test "unexpected end of input":
  check bDecode("l").l == newSeq[BencodeObj]()
  check bDecode("d").d == initOrderedTable[BencodeObj, BencodeObj]()
  check bDecode("d5:hello5:world3:foo").d == { Bencode("hello"): Bencode("world") }.toOrderedTable
