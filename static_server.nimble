import
  ospaths
# Package
version       = "2.2.0"
author        = "bung"
description   = "A tiny static file web server."
license       = "MIT"
bin           = @["static_server"]
srcDir        = "src"
installExt    = @["nim","css"]

# Dependencies

requires "nim >= 1.2.0"
requires "https://github.com/bung87/finder >= 0.2.0"

const compile = "nim c -d:release"
const linux_x64 = "--cpu:amd64 --os:linux -o:static_server"
const windows_x64 = "--cpu:amd64 --os:windows -o:static_server.exe"
const macosx_x64 = "-o:static_server"
const program = "static_server"
const program_file = "src/static_server.nim"
const zip = "zip -X"

proc shell(command, args: string, dest = "") =
  exec command & " " & args & " " & dest

proc filename_for(os: string, arch: string): string =
  return "static_server" & "_v" & version & "_" & os & "_" & arch & ".zip"

task windows_x64_build, "Build static_server for Windows (x64)":
  shell compile, windows_x64, program_file

task linux_x64_build, "Build static_server for Linux (x64)":
  shell compile, linux_x64,  program_file
  
task macosx_x64_build, "Build static_server for Mac OS X (x64)":
  shell compile, macosx_x64, program_file

task release, "Release static_server":
  echo "\n\n\n WINDOWS - x64:\n\n"
  windows_x64_buildTask()
  shell zip, filename_for("windows", "x64"), program & ".exe"
  shell "rm", program & ".exe"
  echo "\n\n\n LINUX - x64:\n\n"
  linux_x64_buildTask()
  shell zip, filename_for("linux", "x64"), program 
  shell "rm", program 
  echo "\n\n\n MAC OS X - x64:\n\n"
  macosx_x64_buildTask()
  shell zip, filename_for("macosx", "x64"), program 
  shell "rm", program 
  echo "\n\n\n ALL DONE!"

