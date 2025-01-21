package main

import "core:os"
import "core:fmt"
print :: fmt.printf

Reg_8bit :: enum {
  // Order is swapped to match hi- and lo- byte status in the register union.
  F, A,
  C, B,
  E, D,
  L, H,
  SPL, SPH,
  PCL, PCH,
}
Reg_16bit :: enum {
  AF, BC, DE, HL, SP, PC
}

Registers :: struct #raw_union {
  byte: [Reg_8bit]u8,
  word: [Reg_16bit]u16,
}

Flags :: enum u8 {
  Zero       = 0x80,
  Negative   = 0x40,
  Half_Carry = 0x20,
  Carry      = 0x10,
}

registers : Registers
regs_byte := &registers.byte
regs_word := &registers.word

// instruction_pointer : u16 = 0x100
program_counter := &regs_word[.PC]
interrupt_master_flag := 1


memory_map : [0xFFFFF]u8

number_of_instructions_executed_succesfully := 0

print_instruction_on_fail_only := true

main :: proc() {
  file, ok := os.read_entire_file_from_filename("D:/codes/gameboy_emulator/gb-test-roms/cpu_instrs/individual/09-op r,r.gb")
  // file, ok := os.read_entire_file_from_filename("D:/codes/gameboy_emulator/gb-test-roms/cpu_instrs/individual/06-ld r,r.gb")
  if !ok {
    print("Couldn't read file\n")
    return
  }
  
  assert(len(file[:])-1 == 0x7FFF)
  copy(memory_map[0x0000:0x7FFF], file[:])
  
  running := true
  program_counter^ = 0x0100
  
  for running {
    decoded_at := program_counter^
    instruction := decode_next(false)
    print("%-16v - 0x %2x; at %v\n", instruction.opcode_string, instruction.reference_byte, decoded_at)
    
    anti_spinlock := 0
    valid := true
    for command_index < len(command_buffer) {
      valid = exec_command(instruction)
      
      anti_spinlock += 1
      if anti_spinlock > 100 {
        panic("Spinlock!")
      }
      if !valid { break }
    }
    
    clear(&command_buffer)
    running_opcode_info = {}
    
    if valid {
      number_of_instructions_executed_succesfully += 1
    } else {
      print("Number of instructions executed: %v\n", number_of_instructions_executed_succesfully)
      running = false
    }
    
    if program_counter^ > 0xFEA0 {
      print("End of the line.\n")
      running = false
    }
    
    
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
      X := 1
      if false {
        print("", A, B, C, D, E, H, L, BC, DE, HL, X)
      }
    }
  }
}