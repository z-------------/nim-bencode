import unittest
import bencode
import tables
import json

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
    check bencode.encode(k) == v
    check bencode.decode(v) == k

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
    data = b({
      b"interval": b(1800),
      b"min interval": b(900),
      b"peers": b("\x0a\x0a\x0a\x05\x00\x80"),
      b"complete": b(20),
      b"incomplete": b(0),
    })
    bencodedData = encode(data)

  check bencodedData == "d8:intervali1800e12:min intervali900e5:peers6:\x0a\x0a\x0a\x05\x00\x808:completei20e10:incompletei0ee"
  check decode(bencodedData) == data

test "dictionary access by string key":
  var b = Bencode({
    "interval": Bencode(1800),
    "complete": Bencode(20),
  })
  check b.d["interval"] == Bencode(1800)
  b.d["complete"] = Bencode(30)
  check b.d["complete"] == Bencode(30)

  check b == b({
    "interval": b(1800),
    "complete": b(30),
  })
