import pkg/bencode/[
  decoding,
  encoding,
]
import std/[
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
