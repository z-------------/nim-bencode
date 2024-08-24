import ./bencode/[
  decoding,
  encoding,
]

export decoding, encoding

when isMainModule:
  import std/os

  proc parseFormatArg(arg: string): BencodeFormat =
    if arg.len < 2: quit("Invalid argument.")
    let c = arg[1]
    case c
    of 'u': Normal
    of 'd': Decimal
    of 'x': Hexadecimal
    else: quit("Invalid format argument '" & arg & "'.")

  let (filename, format) = case paramCount()
    of 0:
      quit("Filename required.")
    of 1:
      (paramStr(1), Normal)
    else:
      block:
        let fnIdx = if paramStr(1)[0] == '-': 2 else: 1
        (paramStr(fnIdx), paramStr(3 - fnIdx).parseFormatArg)
  
  let
    f = open(filename, fmRead)
    obj = bDecode(f)
  echo obj.toString(format)
