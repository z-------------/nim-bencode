import std/streams

type
  InputStream* = concept v
    atEnd(v) is bool
    readChar(var v) is char
    peekChar(v) is char
    getPosition(v) is int
    readStr(var v, int) is string

# StringInputStream

type
  StringInputStream* = object
    s: string
    i: int

proc toInputStream*(s: sink string): StringInputStream =
  StringInputStream(s: s)

proc atEnd*(s: StringInputStream): bool =
  s.i >= s.s.len

proc readChar*(s: var StringInputStream): char =
  if s.atEnd:
    raise (ref IOError)(msg: "no more chars to read")
  result = s.s[s.i]
  inc s.i

proc peekChar*(s: StringInputStream): char =
  if s.atEnd:
    raise (ref IOError)(msg: "no more chars to peek")
  result = s.s[s.i]

proc getPosition*(s: StringInputStream): int =
  s.i

proc readStr*(s: var StringInputStream; len: int): string =
  if s.i + len > s.s.len:
    raise (ref IOError)(msg: "not enough data left to read a string of length " & $len)
  result = s.s[s.i ..< s.i + len]
  inc s.i, len

# StreamInputStream

type
  StreamInputStream* = object
    s: Stream

proc toInputStream*(s: Stream): StreamInputStream =
  StreamInputStream(s: s)

proc atEnd*(s: StreamInputStream): bool =
  s.s.atEnd

proc readChar*(s: var StreamInputStream): char =
  if s.s.atEnd:
    raise (ref IOError)(msg: "no more chars to read")
  result = s.s.readChar

proc peekChar*(s: StreamInputStream): char =
  if s.s.atEnd:
    raise (ref IOError)(msg: "no more chars to peek")
  result = s.s.peekChar

proc getPosition*(s: StreamInputStream): int =
  s.s.getPosition

proc readStr*(s: var StreamInputStream; len: int): string =
  result = s.s.readStr(len)
  if result.len < len:
    raise (ref IOError)(msg: "not enough data left to read a string of length " & $len)
