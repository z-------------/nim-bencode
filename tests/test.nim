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
    data = Bencode({
      Bencode("interval"): Bencode(1800),
      Bencode("min interval"): Bencode(900),
      Bencode("peers"): Bencode("\x0a\x0a\x0a\x05\x00\x80"),
      Bencode("complete"): Bencode(20),
      Bencode("incomplete"): Bencode(0),
    })
    bencodedData = encode(data)

  doAssert bencodedData == "d8:intervali1800e12:min intervali900e5:peers6:\x0a\x0a\x0a\x05\x00\x808:completei20e10:incompletei0ee"
  doAssert decode(bencodedData) == data
