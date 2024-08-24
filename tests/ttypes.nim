import pkg/bencode/types
import std/[
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

test "toBencodeObj":
  let world = "world"

  func getValue(): int =
    314159

  let actual = toBencodeObj({
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

template checkEquals(a, b: BencodeObj) =
  check a == b
  check hash(a) == hash(b)

template checkNotEquals(a, b: BencodeObj) =
  check a != b
  check hash(a) != hash(b)

test "equality":
  checkEquals be"hello", be"hello"
  checkNotEquals be"hello", be"world"
  checkEquals be(100), be(100)
  checkNotEquals be(100), be(200)
  checkEquals be([be"hello", be"world"]), Bencode([be"hello", be"world"])
  checkNotEquals be([be"hello", be"world"]), Bencode([be"world", be"hello"])
  checkEquals be({"hello": be"world", "world": be([be"foo", be(1)])}), be({"hello": be"world", "world": be([be"foo", be(1)])})
  checkNotEquals be({"hello": be"world", "world": be([be"foo", be(1)])}), be({"hello": be"world", "world": be([be"foo", be(2)])})

test "stringify":
  check $be("hello") == """"hello""""
  check be("hello").toString(Normal) == """"hello""""
  check be("hello").toString(Hexadecimal) == """"\x68\x65\x6C\x6C\x6F""""
  check be("hello").toString(Decimal) == """"\d0104\d0101\d0108\d0108\d0111""""
  check $be([be"hello", be(2)]) == """@["hello", 2]"""
  check $be({"hello": be"world", "world": be([be"foo", be(1)])}) == """{ hello: "world", world: @["foo", 1] }"""
