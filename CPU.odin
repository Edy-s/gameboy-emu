package main

cpu_state : struct {
  instr: Instruction,
  instr_clocks: int,
  
  instr_info: struct {
    bytes_set: u8,
    data: struct #raw_union {
      bytes: struct { lsb, msb: u8 },
      word: u16,
    },
    stash: u16,
    stash_set: u8,
  }
}

command_buffer: [dynamic]Command
command_index: int

do_CPU_tick :: proc() -> (valid: bool) {
  valid = true
  conditioned := false
  if len(command_buffer) == 0 {
    assert(cpu_state.instr_clocks == 0)
    cpu_state.instr = decode_next(false)
    cpu_state.instr_clocks += 1
  } else if command_buffer[0].type == .prefix {
    clear(&command_buffer)
    cpu_state.instr = decode_next(true)
    cpu_state.instr_clocks += 1
  } else {
    command_cycles := 0
    for command_cycles == 0 && (command_index < len(command_buffer)) && !conditioned {
      command_cycles, valid, conditioned = exec_command(cpu_state.instr)
      if !valid { break }
      command_index += 1
    }
    cpu_state.instr_clocks += command_cycles
  }
  
  if command_index == len(command_buffer) || conditioned {
    if !((cpu_state.instr_clocks == cpu_state.instr.timing.min) || (cpu_state.instr_clocks == cpu_state.instr.timing.max)) {
      print("\n\nBad timing!\ncycles taken: %v\ninfo: %v\n", cpu_state.instr_clocks, cpu_state.instr)
      valid = false
    }
    
    number_of_instructions_executed_succesfully += 1
    
    clear(&command_buffer)
    command_index = 0
    
    cpu_state.instr_clocks = 0
    cpu_state.instr_info = {}
  }
  
  return valid
}