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
