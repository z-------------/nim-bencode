import std/unittest

template expect*[T: Exception](errorType: typedesc[T]; body: untyped): ref T =
  var exception: ref T = nil
  unittest.expect(errorType):
    try:
      body
    except T as e:
      exception = e
      raise
  exception

template checkDecode*(t: typedesc; data: static string; expected: untyped) =
  # runtime string
  block:
    let d = data
    check t.fromBencode(d) == expected
  # compile-time string
  block:
    const actual = t.fromBencode(data)
    check actual == expected
  # stream
  check t.fromBencode(newStringStream(data)) == expected
