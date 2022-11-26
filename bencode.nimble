# Package

version       = "0.0.5"
author        = "z-------------"
description   = "Bencode for Nim"
license       = "MIT"
srcDir        = "src"
bin           = @["bencode"]
installExt    = @["nim"]

# Dependencies

requires "nim >= 1.4.2"
requires "faststreams >= 0.3.0"
