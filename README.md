# bencode

This is a Nim library to encode/decode [Bencode](https://en.wikipedia.org/wiki/Bencode), the encoding used by the BitTorrent protocol to represent structured data.

## Examples

```nim
import pkg/bencode

const Expected = "d8:completei20e10:incompletei0e8:intervali1800e12:min intervali900e5:peers6:\x0a\x0a\x0a\x05\x00\x80e"
```

### Custom types

```nim
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
```

### BencodeObj and container types

```nim
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
```

Also works with `std/tables`'s `Table` and `OrderedTable` and `std/json`'s `JsonNode`.

### Old API

```nim
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
```
