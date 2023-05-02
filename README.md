# bencode

This is a Nim library to encode/decode [Bencode](https://en.wikipedia.org/wiki/Bencode), the encoding used by the BitTorrent protocol to represent structured data.

## Example

```nim
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

doAssert bencodedData == "d8:completei20e10:incompletei0e8:intervali1800e12:min intervali900e5:peers6:\x0a\x0a\x0a\x05\x00\x80e"
doAssert bDecode(bencodedData) == data
```
