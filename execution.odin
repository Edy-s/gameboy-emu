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
    add_byte_to_info(byte)
    
    valid = true
    cycles_used += 1
  
  case .check_condition:
    cond := get_param(.cond, instruction)
    
    pass: bool
    switch cond {
    case 0: pass = !get_flag(.Zero)
    case 1: pass =  get_flag(.Zero)
    case 2: pass = !get_flag(.Carry)
    case 3: pass =  get_flag(.Carry)
    case: panic("Unreachable")
    }
    if !pass { clear(&command_buffer) }
    
    valid = true
    
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
        if !do_mem_hl { byte = regs.byte[r8_reg] }
        else          { byte = memory_map[regs.word[.HL]]; cycles_used += 1 }
        put_byte_to_info(byte)
        
        valid = true
      }
      if command.type == .store {
        byte := get_info_byte()
        if !do_mem_hl { regs.byte[r8_reg] = byte }
        else          { memory_map[regs.word[.HL]] = byte; cycles_used += 1 }
        
        valid = true
      }
    
    case .pc, .r16, .r16stk, .hl:
      r16_reg: Reg_Word
         
      if action.reg == .r16 {
        r16_value := get_param(action.reg, instruction)
        r16_reg    = r16_mapping[r16_value]
      } else if action.reg == .r16stk {
        r16_value := get_param(action.reg, instruction)
        r16_reg    = r16stk_mapping[r16_value]
      } else if action.reg == .pc {
        r16_reg = .PC
      } else if action.reg == .hl {
        r16_reg = .HL
      }
      
      if command.type == .load {
        put_word_to_info(regs.word[r16_reg])

        valid = true
      }
      if command.type == .store {
        regs.word[r16_reg] = get_info_word()
        
        valid = true
      }
      
    case:
    }
  
  case .read, .write:
    action := command.data.(Memory_Action)
    #partial switch action.address {
    case .r16mem, .stash:
      register: Reg_Word
      change: u16
      address: u16
      
      if action.address == .r16mem {
        r16mem_value := get_param(action.address, instruction)
        register, change = r16mem_mapping(r16mem_value)
        address = regs.word[register]
      } else if action.address == .stash {
        address = get_stash_word()
      }
      
      if      command.type == .read  {
        if address == 0xFF44 { put_byte_to_info(0x90) } // todo: remove when gpu is in place hardcode because no gpu
        else                 { put_byte_to_info(memory_map[address]) }
      }
      else if command.type == .write { memory_map[address] = get_info_byte() }
      
      regs.word[register] += change
      cycles_used += 1
      
      valid = true
    }
  
  case .alu:
    alu_cycles := 0
    valid, alu_cycles = do_alu(command, instruction)
    cycles_used += alu_cycles
    
  case .push:
    byte := pop_info_byte()
    regs.word[.SP] -= 1
    memory_map[regs.word[.SP]] = byte
    
    cycles_used += 1
    valid = true

  case .pop:
    byte := memory_map[regs.word[.SP]]
    regs.word[.SP] += 1
    add_byte_to_info(byte)
    
    cycles_used += 1
    valid = true
    
  case .clear_i:
    // todo: flip this flag on next cycle
    interrupt_master_flag = 0
    valid = true
  
  case .clock:
    cycles_used += 1
    valid = true
  
  case .set_msb:
    assert(running_opcode_info.bytes_set == 1)
    running_opcode_info.data.bytes.msb = 0xFF
    running_opcode_info.bytes_set += 1
    valid = true
  
  case .stash:
    running_opcode_info.stash_set = running_opcode_info.bytes_set
    running_opcode_info.stash     = running_opcode_info.data.word
    running_opcode_info.bytes_set = 0
    running_opcode_info.data.word = 0
    valid = true
    
  case .unstash:
    running_opcode_info.bytes_set = running_opcode_info.stash_set
    running_opcode_info.data.word = running_opcode_info.stash
    running_opcode_info.stash_set = 0
    running_opcode_info.stash     = 0
    valid = true
  case:
  }
  
  if !valid {
    print("Unimplemented command!\n%v\ninstruction params: %v\ninfo: %v; data %4x\n", command_buffer[command_index], instruction.params, running_opcode_info, running_opcode_info.data.word)
  }
  
  assert(cycles_used < 2)
  command_index += 1
  
  return valid
}

get_stash_word :: proc() -> u16 {
  assert(running_opcode_info.stash_set == 2)
  return running_opcode_info.stash
}

get_stash_byte :: proc() -> u8 {
  assert(running_opcode_info.stash_set == 1)
  return u8(running_opcode_info.stash)
}

add_byte_to_info :: proc(byte: u8) {
  if      running_opcode_info.bytes_set == 0 { running_opcode_info.data.bytes.lsb = byte }
  else if running_opcode_info.bytes_set == 1 { running_opcode_info.data.bytes.msb = byte }
  else { panic("Unreachable.") }
  running_opcode_info.bytes_set += 1
}

put_byte_to_info :: proc(byte: u8) {
  assert(running_opcode_info.bytes_set == 0)
  running_opcode_info.data.bytes.lsb = byte
  running_opcode_info.bytes_set += 1
}

put_word_to_info :: proc(word: u16) {
  assert(running_opcode_info.bytes_set == 0)
  running_opcode_info.data.word = word
  running_opcode_info.bytes_set += 2
}

get_info_byte :: proc() -> u8 {
  assert(running_opcode_info.bytes_set == 1)
  running_opcode_info.bytes_set -= 1
  return running_opcode_info.data.bytes.lsb
}

pop_info_byte :: proc() -> u8 {
  assert(running_opcode_info.bytes_set > 0)
  if running_opcode_info.bytes_set == 2 { running_opcode_info.bytes_set -= 1; return running_opcode_info.data.bytes.msb }
  if running_opcode_info.bytes_set == 1 { running_opcode_info.bytes_set -= 1; return running_opcode_info.data.bytes.lsb }
  panic("Unreachable")
}

get_info_word :: proc() -> u16 {
  assert(running_opcode_info.bytes_set == 2)
  running_opcode_info.bytes_set -= 2
  return running_opcode_info.data.word
}

get_param :: proc(type: Op_Param_Type, instr: Instruction) -> u8 {
  for param in instr.params {
    if param.type == type {
      return param.value
    }
  }
  panic("Unreachable.")
}


r8_mapping :: proc(r8_value: u8) -> (reg: Reg_Byte, do_mem_hl: bool) {
  r8_map := [?]Reg_Byte{.B, .C, .D, .E, .H, .L, .F, .A}
  if r8_value != 6 { return r8_map[r8_value], false }
  return .F, true
}

r16mem_mapping :: proc(r16mem_value: u8) -> (reg: Reg_Word, change: u16) {
  r16_map := [?]Reg_Word{.BC, .DE, .HL, .HL}
  reg = r16_map[r16mem_value]
  if r16mem_value == 2 { change = 1 }
  if r16mem_value == 3 { change = transmute(u16)(i16(-1)) }
  
  return reg, change
}

r16_mapping    := [?]Reg_Word{.BC, .DE, .HL, .SP}
r16stk_mapping := [?]Reg_Word{.BC, .DE, .HL, .AF}


get_flag :: proc(flag: Cpu_Flags) -> bool {
  assert(flag != .Half_Carry, "use of this requires real bitwise implementation of math")
  assert(flag != .Negative,   "use of this requires real bitwise implementation of math")
  return flag in flags
}

do_flag :: proc(flag: Cpu_Flags, set: bool) {
  if set { set_flag(flag) }
  else { clear_flag(flag) }
}

set_flag :: proc(flag: Cpu_Flags) {
  flags^ |= {flag}
}

clear_flag :: proc(flag: Cpu_Flags) {
  flags^ &= ~{flag}
}

