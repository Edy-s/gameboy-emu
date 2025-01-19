package main

import "core:os"
import "core:fmt"
print :: fmt.printf

Reg_8bit :: enum {
  // Order is swapped to match hi- and lo- bit status in the register union.
  F, A,
  C, B,
  E, D,
  L, H,
}
Reg_16bit :: enum {
  AF, BC, DE, HL, SP
}

Registers :: struct #raw_union {
  byte: [Reg_8bit]u8,
  word: [Reg_16bit]u16,
}

Flags :: enum u8 {
  Zero       = 0x1,
  Negative   = 0x2,
  Half_Carry = 0x4,
  Carry      = 0x8,
}

registers : Registers
regs_byte := &registers.byte
regs_word := &registers.word

instruction_pointer : u16 = 0x100
interrupt_master_flag := 1


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
      A  := regs_byte[.A]
      B  := regs_byte[.B]
      C  := regs_byte[.C]
      D  := regs_byte[.D]
      E  := regs_byte[.E]
      H  := regs_byte[.H]
      L  := regs_byte[.L]
      BC := regs_word[.BC]
      DE := regs_word[.DE]
      HL := regs_word[.HL]
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