import pkg/bencode

const Expected = "d8:completei20e10:incompletei0e8:intervali1800e12:min intervali900e5:peers6:\x0a\x0a\x0a\x05\x00\x80e"

block:
  type
    Data = object
      interval: int
      minInterval {.name: "min interval".}: int
      peers: string
      complete: int
      incomplete: int

  let
    data = Data(
      interval: 1800,
      minInterval: 900,
      peers: "\x0a\x0a\x0a\x05\x00\x80",
      complete: 20,
      incomplete: 0,
    )
    bencodedData = data.toBencode()

  doAssert bencodedData == Expected
  doAssert Data.fromBencode(bencodedData) == data

import std/tables

block:
  let
    data = {
      "interval": be(1800),
      "min interval": be(900),
      "peers": be("\x0a\x0a\x0a\x05\x00\x80"),
      "complete": be(20),
      "incomplete": be(0),
    }.toTable
    bencodedData = data.toBencode()

  doAssert bencodedData == Expected
  doAssert Table[string, BencodeObj].fromBencode(bencodedData) == data

block:
  let
    data = be({
      "interval": be(1800),
      "min interval": be(900),
      "peers": be("\x0a\x0a\x0a\x05\x00\x80"),
      "complete": be(20),
      "incomplete": be(0),
    })
    bencodedData = data.toBencode

  doAssert bencodedData == Expected
  doAssert BencodeObj.fromBencode(bencodedData) == data

block:
  let
    data = be({
      "interval": be(1800),
      "min interval": be(900),
      "peers": be("\x0a\x0a\x0a\x05\x00\x80"),
      "complete": be(20),
      "incomplete": be(0),
    })
    bencodedData = bEncode(data)

  doAssert bencodedData == Expected
  doAssert bDecode(bencodedData) == data
