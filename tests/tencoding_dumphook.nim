import pkg/bencode/encoding
import std/[
  json,
  unittest,
]

proc dumpHook*(s: var string; v: float) =
  dumpHook(s, int(v * 100))

test "from JsonNode with float and custom dumpHook":
  check (%*{"wow": 3.14}).toBencode == "d3:wowi314ee"
