# Package

version       = "0.1.0"
author        = "C-NERD"
description   = "Unofficial twitter api"
license       = "MIT"
srcDir        = "src"
binDir        = "bin"
installExt    = @["nim"]
bin           = @["twitterapi"]

backend       = "cpp"
# Dependencies

requires "nim >= 1.0.0", "zippy >= 0.7.4"

task make, "Compiles the code as a executable into the bin directory":

    exec "nimble --gc:arc --d:ssl --d:danger --d:release build"