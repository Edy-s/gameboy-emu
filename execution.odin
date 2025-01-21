package main

running_opcode_info : struct {
  bytes_set: u8,
  data: struct #raw_union {
    bytes: struct { lsb, msb: u8 },
    word: u16,
  },
  stash: u16,
  stash_set: u8,
}


exec_command :: proc(instruction: Instruction) -> bool {
  command := command_buffer[command_index]
  cycles_used := 0
  valid := false
  
  #partial switch command.type {
  case .next:
    byte := memory_map[program_counter^]
    program_counter^ += 1
    put_byte_to_info(byte)
    
    valid = true
    cycles_used += 1
  
  case .load, .store:
    action := command.data.(Register_Action)
    
    #partial switch action.reg {
    case .s8, .d8, .r8, .a:
      r8_value: u8
      if action.reg == .a { r8_value = 7 }
      else                { r8_value = get_param(action.reg, instruction) }
      r8_reg, do_mem_hl := r8_mapping(r8_value)
      
      if command.type == .load {
        byte: u8
        if !do_mem_hl { byte = regs_byte[r8_reg] }
        else          { byte = memory_map[regs_word[.HL]]; cycles_used += 1 }
        put_byte_to_info(byte)
        
        valid = true
      }
      if command.type == .store {
        byte := get_info_byte()
        if !do_mem_hl { regs_byte[r8_reg] = byte }
        else          { memory_map[regs_word[.HL]] = byte; cycles_used += 1 }
        
        valid = true
      }
    
    case .pc, .r16:
      r16_reg: Reg_16bit
         
      if action.reg == .r16 {
        r16_value := get_param(.r16, instruction)
        r16_reg = r16_mapping[r16_value]
      } else if action.reg == .pc {
        r16_reg = .PC
      }
      
      if command.type == .load {}
      if command.type == .store {
        regs_word[r16_reg] = get_info_word()
        
        valid = true
      }
      
    case:
    }
  
  // case .store:
  //   action := command.data.(Register_Action)
  //   #partial switch action.reg {
  //   case .pc, .r16:
  //     register: Reg_16bit
      
  //     if action.reg == .r16 {
  //       r16_value := get_param(.r16, instruction)
  //       register = r16_mapping[r16_value]
  //       valid = true
  //     } else if action.reg == .pc {
  //       register = .PC
  //       valid = true
  //     }
      
  //     regs_word[register] = get_info_word()
      
  //   case .d8, .r8:
  //     r8_value := get_param(action.reg, instruction)
      
  //     r8_reg, do_mem_hl := r8_mapping(r8_value)
  //     if !do_mem_hl {
  //       regs_byte[r8_reg] = get_info_byte()
  //       valid = true
  //     } else {
  //     }
    
  //   case .a:
  //     regs_byte[.A] = get_info_byte()
  //     valid = true
      
  //   case:
  //   }
  
  case .read, .write:
    action := command.data.(Memory_Action)
    #partial switch action.address {
    case .r16mem:
      r16mem_value := get_param(action.address, instruction)
      register, change := r16mem_mapping(r16mem_value)
      address := regs_word[register]
      
      if      command.type == .read  { put_byte_to_info(memory_map[address]) }
      else if command.type == .write { memory_map[address] = get_info_byte() }
      
      regs_word[register] += change
      cycles_used += 1
      
      valid = true
    }
  
  case .clock:
    cycles_used += 1
    valid = true
    
  case:
  }
  
  if !valid {
    print("Unimplemented command!\n%v\ninstruction params: %v\n", command_buffer[command_index], instruction.params)
  }
  
  assert(cycles_used < 2)
  command_index += 1
  
  return valid
}

put_byte_to_info :: proc(byte: u8) {
  if      running_opcode_info.bytes_set == 0 { running_opcode_info.data.bytes.lsb = byte }
  else if running_opcode_info.bytes_set == 1 { running_opcode_info.data.bytes.msb = byte }
  else { panic("Unreachable.") }
  running_opcode_info.bytes_set += 1
}

get_info_byte :: proc() -> u8 {
  assert(running_opcode_info.bytes_set == 1)
  return running_opcode_info.data.bytes.lsb
}

get_info_word :: proc() -> u16 {
  assert(running_opcode_info.bytes_set == 2)
  return running_opcode_info.data.word
}

get_param :: proc(type: Op_Param_Type, instr: Instruction) -> u8 {
  result: u8
  found := false
  for param in instr.params {
    if param.type == type {
      found = true
      result = param.value
    }
  }
  if !found { panic("Unreachable.") }
  return result
}


r8_mapping :: proc(r8_value: u8) -> (reg: Reg_8bit, do_mem_hl: bool) {
  r8_map := [?]Reg_8bit{.B, .C, .D, .E, .H, .L, .F, .A}
  if r8_value != 6 { return r8_map[r8_value], false }
  return .F, true
}

r16mem_mapping :: proc(r16mem_value: u8) -> (reg: Reg_16bit, change: u16) {
  r16_map := [?]Reg_16bit{.BC, .DE, .HL, .HL}
  reg = r16_map[r16mem_value]
  if r16mem_value == 2 { change = 1 }
  if r16mem_value == 3 { change = transmute(u16)(i16(-1)); panic("check this") }
  
  return reg, change
}

r16_mapping    := [?]Reg_16bit{.BC, .DE, .HL, .SP}
r16stk_mapping := [?]Reg_16bit{.BC, .DE, .HL, .AF}