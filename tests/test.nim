import ./utils
import pkg/bencode
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
        }
      ]
    }
    """)
    actual = Bencode({
      "foo": Bencode(69),
      "bar": Bencode(@[
        Bencode({
          "baz": Bencode(420),
          "qux": Bencode(6969),
        }),
      ]),
    }).toJson

  check actual == expected

test "conversion from json":
  let
    expected = Bencode({
      "foo": Bencode(69),
      "bar": Bencode(@[
        Bencode({
          "baz": Bencode(420),
          "qux": Bencode(6969),
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

test "dictionary access by string key":
  var b = Bencode({
    "interval": Bencode(1800),
    "complete": Bencode(20),
  })
  check b.d["interval"] == Bencode(1800)
  b.d["complete"] = Bencode(30)
  check b.d["complete"] == Bencode(30)

  check b == be({
    "interval": be(1800),
    "complete": be(30),
  })

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
  check bDecode("d").d == initOrderedTable[string, BencodeObj]()
  check bDecode("d5:hello5:world3:foo").d == { "hello": Bencode("world") }.toOrderedTable

test "toBencode":
  let world = "world"

  func getValue(): int =
    314159

  let actual = toBencode({
    "foo": [1, 2, 3],
    "bar": {
      "nested": getValue(),
      "nested2": [
        {
          "bar": "hello " & world,
        },
      ],
    },
    "paren": (3 + 4),
    "empty list": [],
    "empty dict": {:},
  })
  let expected = Bencode({
    "foo": Bencode([Bencode(1), Bencode(2), Bencode(3)]),
    "bar": Bencode({
      "nested": Bencode(314159),
      "nested2": Bencode([
        Bencode({
          "bar": Bencode("hello world"),
        })
      ]),
    }),
    "paren": Bencode(7),
    "empty list": BencodeObj(kind: bkList),
    "empty dict": BencodeObj(kind: bkDict),
  })
  check actual == expected

test "catch wrong dictionary key kind":
  const data = "d4:name4:dmdmi123e3:nim3:agei50e5:alistli1e2:hiee"
  let exception =
    expect(ValueError):
      discard bDecode(data)
  check exception.msg == "invalid dictionary key: expected string, got integer"
