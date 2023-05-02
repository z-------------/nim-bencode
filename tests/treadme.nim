import pkg/bencode

let
  data = be({
    "interval": be(1800),
    "min interval": be(900),
    "peers": be("\x0a\x0a\x0a\x05\x00\x80"),
    "complete": be(20),
    "incomplete": be(0),
  })
  bencodedData = bEncode(data)

doAssert bencodedData == "d8:intervali1800e12:min intervali900e5:peers6:\x0a\x0a\x0a\x05\x00\x808:completei20e10:incompletei0ee"
doAssert bDecode(bencodedData) == data
