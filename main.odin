package main

import "core:os"
import "core:fmt"

main :: proc() {
  file, ok := os.read_entire_file_from_filename("D:/codes/gameboy_emulator/gb-test-roms/cpu_instrs/individual/09-op r,r.gb")
  if !ok {
    fmt.printf("Couldn't read file\n")
    return
  }
  
  for byte in file {
    if byte == 0 { continue }
    fmt.printf("%x\n", byte)
  }
}