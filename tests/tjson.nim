import pkg/bencode
import pkg/bencode/json
import std/[
  json,
  unittest,
]

test "conversion to json":
  let
    expected = parseJson("""
    {
      "foo": 69,
      "bar": [
        {
          "baz": 420,
          "qux": 6969,
        }
      ]
    }
    """)
    actual = Bencode({
      "foo": Bencode(69),
      "bar": Bencode(@[
        Bencode({
          "baz": Bencode(420),
          "qux": Bencode(6969),
        }),
      ]),
    }).toJson

  check actual == expected

test "conversion from json":
  let
    expected = Bencode({
      "foo": Bencode(69),
      "bar": Bencode(@[
        Bencode({
          "baz": Bencode(420),
          "qux": Bencode(6969),
        }),
        Bencode(3),  # float truncation
      ]),
    })
    actual = parseJson("""
    {
      "foo": 69,
      "bar": [
        {
          "baz": 420,
          "qux": 6969
        },
        3.14159
      ]
    }
    """).fromJson

  check actual == expected
