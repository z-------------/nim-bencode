import pkg/bencode
import std/[
  random,
  strutils,
  strformat,
]

proc generateStr(len: Natural): string =
  # const Chars = {0.char .. 255.char}
  # const Chars = Letters + Digits
  const Chars = {'x'}

  result = newStringOfCap(len)
  for _ in 0..<len:
    result &= sample(Chars)

proc generateBencode(outFile: File; depth: Natural; possibleKinds: set[BencodeKind])

proc generateBencodeStr(outFile: File) =
  let len = rand(0..100)
  let str = generateStr(len)
  outFile.write &"{str.len}:{str}"

proc generateBencodeInt(outFile: File) =
  let n = rand(-0xFFFF..0xFFFF)
  outFile.write &"i{n}e"

proc generateBencodeDict(outFile: File; depth: Natural; count: Natural) =
  outFile.write "d"
  for _ in 0..<count:
    let possibleKinds =
      if depth > 5:
        {bkStr, bkInt}
      else:
        {BencodeKind.low .. BencodeKind.high}
    generateBencode(outFile, depth + 1, {bkStr, bkInt}) # key
    generateBencode(outFile, depth + 1, possibleKinds) # value
  outFile.write "e"

proc generateBencodeList(outFile: File; depth: Natural; count: Natural) =
  outFile.write "l"
  for _ in 0..<count:
    let possibleKinds =
      if depth > 5:
        {bkStr, bkInt}
      else:
        {BencodeKind.low .. BencodeKind.high}
    generateBencode(outFile, depth + 1, possibleKinds)
  outFile.write "e"

proc generateBencode(outFile: File; depth: Natural; possibleKinds: set[BencodeKind]) =
  const CountRange = 0..15

  let kind = sample(possibleKinds)
  case kind
  of bkStr:
    generateBencodeStr(outFile)
  of bkInt:
    generateBencodeInt(outFile)
  of bkList:
    generateBencodeList(outFile, depth, count = rand(CountRange))
  of bkDict:
    generateBencodeDict(outFile, depth, count = rand(CountRange))


when isMainModule:
  randomize()
  generateBencodeList(stdout, depth = 0, count = 5)
