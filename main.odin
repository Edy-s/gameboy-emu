package main

import "core:os"
import "core:fmt"
print :: fmt.printf

Registers :: enum {
  A, F, B, C, D, E, H, L
}
Fat_Registers :: enum {
  AF, BC, DE, HL
}
Flags :: enum u8 {
  Zero       = 0x1,
  Negative   = 0x2,
  Half_Carry = 0x4,
  Carry      = 0x8,
}

registers : [Registers]u8
stack_pointer : u16
instruction_pointer :u16= 0x100

memory_map : [0xFFFFF]u8

number_of_instructions_executed_succesfully := 0

print_instruction_on_fail_only := true

main :: proc() {
  file, ok := os.read_entire_file_from_filename("D:/codes/gameboy_emulator/gb-test-roms/cpu_instrs/individual/09-op r,r.gb")
  if !ok {
    print("Couldn't read file\n")
    return
  }
  
  assert(len(file[:])-1 == 0x7FFF)
  copy(memory_map[0x0000:0x7FFF], file[:])
  
  
  running := true
  
  for running {
    instruction := decode_next_instruction()
    
    if instruction_pointer > 0xFEA0 {
      print("End of the line.\n")
      running = false
    }
    
    execution_succeded := execute_instruction(instruction)
    
    {
      A  := registers[.A]
      B  := registers[.B]
      C  := registers[.C]
      D  := registers[.D]
      E  := registers[.E]
      H  := registers[.H]
      L  := registers[.L]
      BC := fat_register_value(.BC)
      DE := fat_register_value(.DE)
      HL := fat_register_value(.HL)
      x := 1.2 // Debug point
    }
    
    if execution_succeded {
      number_of_instructions_executed_succesfully += 1
    } else {
      if print_instruction_on_fail_only do pretty_print_instruction(instruction)
      running = false
    }
  }
  print("Number of instructions executed: %v\n", number_of_instructions_executed_succesfully)
}