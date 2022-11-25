# bencode

This is a Nim library to encode/decode [Bencode](https://en.wikipedia.org/wiki/Bencode), the encoding used by the BitTorrent protocol to represent structured data.

## Example

```nim
import bencode

let
  data = b({
    b"interval": b(1800),
    b"min interval": b(900),
    b"peers": b("\x0a\x0a\x0a\x05\x00\x80"),
    b"complete": b(20),
    b"incomplete": b(0),
  })
  bencodedData = encode(data)

doAssert bencodedData == "d8:intervali1800e12:min intervali900e5:peers6:\x0a\x0a\x0a\x05\x00\x808:completei20e10:incompletei0ee"
doAssert decode(bencodedData) == data
```
