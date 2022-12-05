# bencode

This is a Nim library to encode/decode [Bencode](https://en.wikipedia.org/wiki/Bencode), the encoding used by the BitTorrent protocol to represent structured data.

## Example

```nim
import bencode

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
```
