import ./utils
import pkg/bencode/decoding
import std/[
  streams,
  strutils,
  unittest,
]

test "execution terminates for invalid bencode input":
  const data = "d4:name4:dmdm4:lang3:nim3:agei50e5:alistli1e2:hiee"
  for i in 0 .. data.high:
    if i in {0, 30, 31, 35..40}:
      # input is valid even if we remove these indexes
      continue
    let invalidData = data[0 .. i - 1] & data[i + 1 .. ^1]
    try:
      discard bDecode(invalidData)
    except BencodeDecodeError:
      discard

test "string too short":
  let exception =
    expect BencodeDecodeError:
      discard bDecode("10:hello")
  check exception.kind == SyntaxError

test "invalid string length":
  let exception =
    expect BencodeDecodeError:
      discard bDecode("-5:hello")
  check exception.kind == InvalidValue
  check "invalid string length" in exception.msg

test "unexpected end of input":
  var exception: ref BencodeDecodeError
  exception =
    expect BencodeDecodeError:
      discard bDecode("l")
  check exception.kind == SyntaxError
  check "expected 'e'" in exception.msg

  exception =
    expect BencodeDecodeError:
      discard bDecode("d")
  check exception.kind == SyntaxError
  check "expected 'e'" in exception.msg

  exception =
    expect BencodeDecodeError:
      discard bDecode("d5:hello5:world3:foo3:bar")
  check exception.kind == SyntaxError
  check "expected 'e'" in exception.msg

  exception =
    expect BencodeDecodeError:
      discard bDecode("d5:hello5:world3:foo")
  check exception.kind == SyntaxError
  check "expected value" in exception.msg

  exception =
    expect BencodeDecodeError:
      discard bDecode("d5:hello5:world3:fooe")
  check exception.kind == SyntaxError
  check "expected value" in exception.msg

  exception =
    expect BencodeDecodeError:
      echo bDecode("5")
  check exception.kind == SyntaxError
  check "expected ':'" in exception.msg

test "catch wrong dictionary key kind":
  const data = "d4:name4:dmdmi123e3:nim3:agei50e5:alistli1e2:hiee"
  let exception =
    expect BencodeDecodeError:
      discard bDecode(data)
  check exception.kind == SyntaxError
  check exception.msg == "invalid integer: i123e3"

test "various input types":
  const expected = ["hello", "world", "!!"]
  checkDecode(array[3, string], "l5:hello5:world2:!!ee", expected)
