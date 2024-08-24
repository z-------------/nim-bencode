import std/[
  os,
  strformat,
  strutils,
]

if paramCount() < 1:
  quit "no filename given"
let
  filename = paramStr(1)
  name = filename.splitFile.name
var
  f = File nil
  i = 0
for line in lines(filename):
  if f == nil:
    if line.strip == "```nim":
      let outFilename = &"{name}_{i}.nim"
      f = open(outFilename, fmWrite)
      inc i
      echo outFilename
  else:
    if line.strip == "```":
      f.close
    else:
      f.writeLine(line)
