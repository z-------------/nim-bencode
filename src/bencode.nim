import bencodepkg/[core, json]

export core, json

when isMainModule:
  import os

  proc die(msg: string; code = 1) {.noReturn.} =
    stderr.writeLine(msg)
    quit(code)

  proc parseFormatArg(arg: string): BencodeFormat =
    if arg.len < 2: die("Invalid argument.")
    let c = arg[1]
    case c
    of 'u': Normal
    of 'd': Decimal
    of 'x': Hexadecimal
    else: die("Invalid format argument '" & arg & "'.")

  let (filename, format) = case paramCount()
    of 0:
      die("Filename required.")
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
