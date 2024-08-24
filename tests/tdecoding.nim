import ./utils
import pkg/bencode/decoding
import std/[
  strutils,
  tables,
  unittest,
]

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
  let exception =
    expect ValueError:
      discard bDecode("10:hello")
  check "string too short" in exception.msg

test "invalid string length":
  let exception =
    expect ValueError:
      discard bDecode("-5:hello")
  check "invalid string length" in exception.msg

test "unexpected end of input":
  const ExpectedMsg = "expected 'e'"

  var exception: ref ValueError
  exception =
    expect ValueError:
      discard bDecode("l")
  check ExpectedMsg in exception.msg
  exception =
    expect ValueError:
      discard bDecode("d")
  check ExpectedMsg in exception.msg
  exception =
    expect ValueError:
      discard bDecode("d5:hello5:world3:foo")
  check ExpectedMsg in exception.msg
  exception =
    expect ValueError:
      echo bDecode("5")
  check "expected ':'" in exception.msg

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
  check exception.msg == "invalid integer: i123e3"

test "deserialization to (ref) object":
  type
    Record = object
      name: string
      lang: string
      age: int
      alist: seq[BencodeObj]

  let expectedRecord = Record(
    name: "dmdm",
    lang: "nim",
    age: 50,
    alist: @[Bencode(1), Bencode("hi")],
  )

  const data = "d3:agei50e5:alistli1e2:hie4:lang3:nim4:name4:dmdme"
  check Record.fromBencode(data) == expectedRecord
  let refRecord = (ref Record).fromBencode(data)
  check refRecord != nil
  check refRecord[] == expectedRecord
  # test the nonsensical overload
  check data.fromBencode(Record) == expectedRecord

test "various table types":
  const data = "d3:agei50e5:alistli1e2:hie4:lang3:nim4:name4:dmdme"
  let expectedTablePairs = {
    "age": Bencode(50),
    "alist": Bencode(@[Bencode(1), Bencode("hi")]),
    "lang": Bencode("nim"),
    "name": Bencode("dmdm"),
  }
  check OrderedTable[string, BencodeObj].fromBencode(data) == expectedTablePairs.toOrderedTable
  check Table[string, BencodeObj].fromBencode(data) == expectedTablePairs.toTable
