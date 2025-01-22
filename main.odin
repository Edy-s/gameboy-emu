package main

import "core:os"
import "core:fmt"
import "core:mem"
import "core:strings"
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

interrupt_master_flag := 1

memory_map : [0xFFFFF]u8
cycle_index := 0

number_of_instructions_executed_succesfully := 0

main :: proc() {
  {
    filename: string
    if len(os.args) > 1 { filename = os.args[1] }
    else {
      print("Provide first arg as filename.\n")
      return
    }
    
    file, ok := os.read_entire_file_from_filename(filename)
    if !ok {
      print("Couldn't read file!\n")
      return
    }
    
    assert(len(file[:])-1 == 0x7FFF)
    copy(memory_map[0x0000:0x7FFF], file[:])
  }
  
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

  serial_data: [dynamic]u8
  
  gb_doc_log := strings.builder_make()
  
  RUN_GAPS :: 3_000_000
  execution_cutoff := RUN_GAPS
  
  serial_finish := 100_000_000
  
  running := true
  for running {
    if len(os.args) > 2 {
      print_for_doc(&gb_doc_log)
    }
    
    instruction_cycles := 1
    instruction := decode_next(false)
    if len(command_buffer) > 0 && command_buffer[0].type == .prefix {
      clear(&command_buffer)
      instruction = decode_next(true)
      instruction_cycles += 1
    }
    // print("%-16v - 0x %2x; at %v\n", instruction.opcode_string, instruction.reference_byte, decoded_at)
    
    valid := true
    for command_index < len(command_buffer) {
      command_cycles := 0
      command_cycles, valid = exec_command(instruction)
      instruction_cycles += command_cycles
      
      if !valid { break }
    }
    
    if !((instruction_cycles == instruction.timing.min) || (instruction_cycles == instruction.timing.max)) {
      print("\n\nBad timing!\ncycles taken: %v\ninfo: %v\n", instruction_cycles, instruction)
      running = false
    }
      
    
    clear(&command_buffer)
    running_opcode_info = {}
    
    if valid {
      number_of_instructions_executed_succesfully += 1
    } else {
      running = false
    }
    
    if number_of_instructions_executed_succesfully > serial_finish { running = false }
    
    /*
    if number_of_instructions_executed_succesfully > execution_cutoff {
      print("x to stop: ")
      in_thing: [10]u8
      os.read(os.stdin, in_thing[:])
      if in_thing[0] == 'x' { running = false }
      execution_cutoff += RUN_GAPS
    }*/
    
    if memory_map[0xFF02] & 0x80 != 0 {
      print("%c", memory_map[0xFF01])
      append(&serial_data, memory_map[0xFF01])
      
      pass_string := "Passed"
      pass_u8 := transmute([]u8)pass_string
      if len(serial_data) > 9 && mem.compare(serial_data[len(serial_data) - 7 : len(serial_data) - 1], pass_u8) == 0 { serial_finish = number_of_instructions_executed_succesfully + 1000000 }
      memory_map[0xFF02] &= ~u8(0x80)
    }
  }
  if strings.builder_len(gb_doc_log) > 0 { os.write_entire_file("doctor.log", transmute([]u8)strings.to_string(gb_doc_log)) }
  print("Number of instructions executed: %v\n", number_of_instructions_executed_succesfully)
}