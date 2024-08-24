import pkg/bencode/encoding
import std/[
  json,
  unittest,
]

test "from JsonNode":
  let j = %*{"foo": "bar", "baz": [1, "qux", true]}
  check j.toBencode == "d3:bazli1e3:quxi1ee3:foo3:bare"

  expect BencodeEncodeError:
    discard (%*{"wow": 3.14}).toBencode
