package main

import "core:os"
import "core:fmt"
print :: fmt.printf

Reg_Byte :: enum {
  // Order is swapped to match hi- and lo- byte status in the register union.
  F, A,
  C, B,
  E, D,
  L, H,
  SPL, SPH,
  PCL, PCH,
}
Reg_Word :: enum {
  AF, BC, DE, HL, SP, PC
}

Flag_Register :: bit_set[Cpu_Flags; u8]
Cpu_Flags :: enum u8 {
  Zero       = 7,
  Negative   = 6,
  Half_Carry = 5,
  Carry      = 4,
}

Registers :: struct #raw_union {
  flags: Flag_Register,
  byte:  [Reg_Byte]u8,
  word:  [Reg_Word]u16,
}
regs : Registers
flags := &regs.flags

program_counter := &regs.word[.PC]
interrupt_master_flag := 1

memory_map : [0xFFFFF]u8

number_of_instructions_executed_succesfully := 0

print_instruction_on_fail_only := true

main :: proc() {
  // file, ok := os.read_entire_file_from_filename("D:/codes/gameboy_emulator/gb-test-roms/cpu_instrs/individual/09-op r,r.gb")
  file, ok := os.read_entire_file_from_filename("D:/codes/gameboy_emulator/gb-test-roms/cpu_instrs/individual/03-op sp,hl.gb")
  if !ok {
    print("Couldn't read file\n")
    return
  }
  
  assert(len(file[:])-1 == 0x7FFF)
  copy(memory_map[0x0000:0x7FFF], file[:])
  
  running := true
  program_counter^ = 0x0100
  
  regs.byte[.A] = 0x01
  regs.byte[.F] = 0xB0
  regs.byte[.B] = 0x00
  regs.byte[.C] = 0x13
  regs.byte[.D] = 0x00
  regs.byte[.E] = 0xD8
  regs.byte[.H] = 0x01
  regs.byte[.L] = 0x4D
  regs.word[.SP] = 0xFFFE
  regs.word[.PC] = 0x0100

  transfer: bool
  serial_data: [dynamic]u8
  
  for running {
    if len(os.args) > 1 { print("A:%2x F:%2x B:%2x C:%2x D:%2x E:%2x H:%2x L:%2x SP:%4x PC:%4x PCMEM:%2x,%2x,%2x,%2x\n", regs.byte[.A], regs.byte[.F], regs.byte[.B], regs.byte[.C], regs.byte[.D], regs.byte[.E], regs.byte[.H], regs.byte[.L], regs.word[.SP], regs.word[.PC], memory_map[program_counter^], memory_map[program_counter^+1], memory_map[program_counter^+2], memory_map[program_counter^+3]) }
    
    // decoded_at := program_counter^
    instruction := decode_next(false)
    if len(command_buffer) > 0 && command_buffer[0].type == .prefix {
      clear(&command_buffer)
      instruction = decode_next(true)
    }
    // print("%-16v - 0x %2x; at %v\n", instruction.opcode_string, instruction.reference_byte, decoded_at)
    
    valid := true
    for command_index < len(command_buffer) {
      valid = exec_command(instruction)
      
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
    
    if memory_map[0xFF02] & 0x80 != 0 { transfer = true }
    if transfer {
      // print("Test serial received: %c\n", memory_map[0xFF01])
      
      memory_map[0xFF02] &= ~u8(0x80)
      transfer = false
      // running = false
    }
    
    {
      A  := regs.byte[.A]
      B  := regs.byte[.B]
      C  := regs.byte[.C]
      D  := regs.byte[.D]
      E  := regs.byte[.E]
      H  := regs.byte[.H]
      L  := regs.byte[.L]
      BC := regs.word[.BC]
      DE := regs.word[.DE]
      HL := regs.word[.HL]
      SP := regs.word[.SP]
      X := 1
      if false {
        print("", A, B, C, D, E, H, L, BC, DE, HL, SP, X)
      }
    }
  }
}