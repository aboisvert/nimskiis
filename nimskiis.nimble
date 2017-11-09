mode = ScriptMode.Verbose

# Package
version       = "0.1"
author        = "Alex Boisvert"
description   = "Parallel Skiis Collection"
license       = "Private"

srcDir = "src"

# Deps

requires "nim >= 0.17.0"

--forceBuild


task clean, "Clean development area":
  rmFile "src/libnimskiis.dylib"
  rmFile "tests/liball_tests.dylib"
  rmFile "tests/all_tests"

  rmDir "src/nimcache"
  rmDir "src/nimskiis/nimcache"
  rmDir "tests/nimcache"

task lib, "Compile sources and produce a lib":
  exec "nim c --threads:on --app:lib src/nimskiis.nim"
  exec "nim c --threads:on --path:../src tests/all_tests"

task tests, "Run all tests":
  withDir "tests":
    exec "nim c --threads:on --path:../src -r all_tests"
