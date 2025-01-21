package main

running_opcode_info : struct {
  bytes_set: u8,
  data: struct #raw_union {
    bytes: struct { lsb, msb: u8 },
    word: u16,
  },
  stash: u16
}


exec_command :: proc() -> bool {
  command := command_buffer[command_index]
  cycles_used := 0
  valid := true
  
  #partial switch command.type {
  case .next:
    byte := memory_map[program_counter^]
    
    if      running_opcode_info.bytes_set == 0 { running_opcode_info.data.bytes.lsb = byte }
    else if running_opcode_info.bytes_set == 1 { running_opcode_info.data.bytes.msb = byte }
    else { panic("Unreachable.") }
    
    running_opcode_info.bytes_set += 1
    program_counter^ += 1
    
    cycles_used += 1
  
  case .store:
    action := command.data.(Register_Action)
    #partial switch action.reg {
    case .pc:
      assert(running_opcode_info.bytes_set == 2)
      regs_word[.PC] = running_opcode_info.data.word
    case:
      valid = false
    }
    
  case .clock:
    cycles_used += 1
    
  case:
    valid = false
  }
  
  if !valid {
    print("Unimplemented command! %v\n", command_buffer[command_index])
  }
  
  command_index += 1
  
  return valid
}
