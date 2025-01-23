package main

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

init_CPU :: proc() {
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
}

do_CPU_tick :: proc() -> (valid: bool) {
  if cycle_index % 4 == 0 { return true }
  valid = true
  conditioned := false
  tick_done := false
  for !tick_done && valid {
    if instr_state == {} {
      instr_state.op, command_buffer = decode_next(false)
      tick_done = true
    } else if command_buffer[0].type == .prefix {
      instr_state.op, command_buffer = decode_next(true)
      tick_done = true
    } else {
      command_cycles := 0
      for command_cycles == 0 && has_commands() && !conditioned {
        command_cycles, valid, conditioned = exec_command(get_command(), instr_state.op)
        if !valid { break }
        command_index += 1
      }
      if command_cycles == 1 { tick_done = true }
    }
    
    if tick_done { instr_state.cycles += 1 }
    
    if command_index == len(command_buffer) || conditioned {
      if !((instr_state.cycles == instr_state.op.timing.min) || (instr_state.cycles == instr_state.op.timing.max)) {
        print("\n\nBad timing!\ncycles taken: %v\ninfo: %v\n", instr_state.cycles, instr_state.op)
        valid = false
      }
      
      number_of_instructions_executed_succesfully += 1
      
      command_index = 0
      
      instr_state = {}
      conditioned = false
    }
  }
  
  
  return valid
}

instr_state : struct {
  op: Opcode,
  cycles: int,
  
  info: struct {
    bytes_set: u8,
    data: struct #raw_union {
      bytes: struct { lsb, msb: u8 },
      word: u16,
    },
    stash: u16,
    stash_set: u8,
  },
}

@(private = "file")
command_buffer: []Command
@(private = "file")
command_index:  int

get_command :: proc() -> Command {
  return command_buffer[command_index]
}

has_commands :: proc() -> bool {
  return command_index < len(command_buffer)
}