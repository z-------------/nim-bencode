import pkg/bencode/decoding
import std/[
  times,
  unittest,
]

proc parseHook*(s: var InputStream; v: var DateTime) =
  var str = ""
  parseHook(s, str)
  v = times.parse(str, "yyyy-MM-dd'T'HH:mm:ssz", utc())

test "custom parseHook":
  type
    Foo = object
      c: int
      date: DateTime
      e: string

  check Foo.fromBencode("d1:ci42e4:date20:2020-01-01T10:20:30Z1:e2:hie") == Foo(
    c: 42,
    date: dateTime(2020, mJan, 1, 10, 20, 30, zone = utc()),
    e: "hi",
  )
