import pkg/bencode/types
import std/[
  unittest,
]

test "toBencodeObj":
  let world = "world"

  func getValue(): int =
    314159

  let actual = toBencodeObj({
    "foo": [1, 2, 3],
    "bar": {
      "nested": getValue(),
      "nested2": [
        {
          "bar": "hello " & world,
        },
      ],
    },
    "paren": (3 + 4),
    "empty list": [],
    "empty dict": {:},
  })
  let expected = Bencode({
    "foo": Bencode([Bencode(1), Bencode(2), Bencode(3)]),
    "bar": Bencode({
      "nested": Bencode(314159),
      "nested2": Bencode([
        Bencode({
          "bar": Bencode("hello world"),
        })
      ]),
    }),
    "paren": Bencode(7),
    "empty list": BencodeObj(kind: bkList),
    "empty dict": BencodeObj(kind: bkDict),
  })
  check actual == expected
