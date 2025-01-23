package main

exec_command :: proc(command: Command, opcode: Opcode) -> (cycles_used: int, valid: bool, conditioned: bool) {
  #partial switch command.type {
  case .next:
    byte := read_at(regs.word[.PC])
    regs.word[.PC] += 1
    add_byte_to_info(byte)
    
    valid = true
    cycles_used += 1
  
  case .check_condition:
    cond := get_param(.cond, opcode)
    
    pass: bool
    switch cond {
    case 0: pass = !get_flag(.Zero)
    case 1: pass =  get_flag(.Zero)
    case 2: pass = !get_flag(.Carry)
    case 3: pass =  get_flag(.Carry)
    case: panic("Unreachable")
    }
    if !pass { conditioned = true }
    
    valid = true
    
  case .load, .store:
    action := command.data.(Register_Action)
    
    #partial switch action.reg {
    case .s8, .d8, .r8, .a, .c:
      r8_value: u8
      if      action.reg == .a { r8_value = 7 }
      else if action.reg == .c { r8_value = 1 }
      else                     { r8_value = get_param(action.reg, opcode) }
      r8_reg, do_mem_hl := r8_mapping(r8_value)
      
      if command.type == .load {
        byte: u8
        if !do_mem_hl { byte = regs.byte[r8_reg] }
        else          { byte = read_at(regs.word[.HL]); cycles_used += 1 }
        put_byte_to_info(byte)
        
        valid = true
      }
      if command.type == .store {
        byte := get_info_byte()
        if !do_mem_hl { regs.byte[r8_reg] = byte }
        else          { write_at(regs.word[.HL], byte); cycles_used += 1 }
        
        valid = true
      }
    
    case .pc, .r16, .r16stk, .hl, .sp, .r16mem:
      r16_reg: Reg_Word
      r16mem_change: u16
         
      if action.reg == .r16 {
        r16_value := get_param(action.reg, opcode)
        r16_reg    = r16_mapping[r16_value]
      } else if action.reg == .r16stk {
        r16_value := get_param(action.reg, opcode)
        r16_reg    = r16stk_mapping[r16_value]
      } else if action.reg == .r16mem {
        r16_value := get_param(action.reg, opcode)
        r16_reg, r16mem_change = r16mem_mapping(r16_value)
      } else if action.reg == .pc {
        r16_reg = .PC
      } else if action.reg == .hl {
        r16_reg = .HL
      } else if action.reg == .sp {
        r16_reg = .SP
      }
      
      if command.type == .load {
        put_word_to_info(regs.word[r16_reg])

        valid = true
      }
      if command.type == .store {
        regs.word[r16_reg] = get_info_word()
        if r16_reg == .AF { regs.byte[.F] &= 0xF0 } // Aparently, the other bits of flag register don't exist in reality!
        
        valid = true
      }
      
      if action.reg == .r16mem {
        regs.word[.HL] += r16mem_change
      }
    
    case .spl, .sph:
      byte := action.reg == .spl ? regs.byte[.SPL] : regs.byte[.SPH]
      put_byte_to_info(byte)
      
      valid = true
      
    }
  
  case .read, .write:
    address := get_stash_word()
    if command.type == .read {
      if address == 0xFF44 { put_byte_to_info(0x90) } // todo: remove when gpu is in place hardcode because no gpu
      else                 { put_byte_to_info(read_at(address)) }
    }
    else if command.type == .write { write_at(address, get_info_byte()) }
    
    cycles_used += 1
    valid = true
  
  case .alu:
    alu_cycles := 0
    valid, alu_cycles = do_alu(command, opcode)
    cycles_used += alu_cycles
    
  case .push:
    byte := pop_info_byte()
    regs.word[.SP] -= 1
    write_at(regs.word[.SP], byte)
    
    cycles_used += 1
    valid = true

  case .pop:
    byte := read_at(regs.word[.SP])
    regs.word[.SP] += 1
    add_byte_to_info(byte)
    
    cycles_used += 1
    valid = true
  
  case .rst:
    address := get_param(.tgt3, opcode)
    regs.word[.PC] = u16(address * 0x08)
    
    cycles_used += 1
    valid = true

  case .set_i:
    // todo: flip this flag on next cycle
    interrupt_master_flag = 1
    valid = true    
  case .clear_i:
    // todo: flip this flag on next cycle
    interrupt_master_flag = 0
    valid = true
  
  case .clock:
    cycles_used += 1
    valid = true
  
  case .set_msb:
    assert(instr_state.info.bytes_set == 1)
    instr_state.info.data.bytes.msb = 0xFF
    instr_state.info.bytes_set += 1
    valid = true
  
  case .stash:
    instr_state.info.stash_set = instr_state.info.bytes_set
    instr_state.info.stash     = instr_state.info.data.word
    instr_state.info.bytes_set = 0
    instr_state.info.data.word = 0
    valid = true
  case .unstash:
    instr_state.info.bytes_set = instr_state.info.stash_set
    instr_state.info.data.word = instr_state.info.stash
    instr_state.info.stash_set = 0
    instr_state.info.stash     = 0
    valid = true
  case .inc_stash:
    instr_state.info.stash += 1
    valid = true
  }
  
  if !valid {
    print("Unimplemented command!\n%v\nopcode params: %v\ninfo: %v; data %4x\n", get_command(), opcode.params, instr_state.info, instr_state.info.data.word)
  }
  
  assert(cycles_used < 2)
  return cycles_used, valid, conditioned
}

get_stash_word :: proc() -> u16 {
  assert(instr_state.info.stash_set == 2)
  return instr_state.info.stash
}

get_stash_byte :: proc() -> u8 {
  assert(instr_state.info.stash_set == 1)
  return u8(instr_state.info.stash)
}

add_byte_to_info :: proc(byte: u8) {
  if      instr_state.info.bytes_set == 0 { instr_state.info.data.bytes.lsb = byte }
  else if instr_state.info.bytes_set == 1 { instr_state.info.data.bytes.msb = byte }
  else { panic("Unreachable.") }
  instr_state.info.bytes_set += 1
}

put_byte_to_info :: proc(byte: u8) {
  assert(instr_state.info.bytes_set == 0)
  instr_state.info.data.bytes.lsb = byte
  instr_state.info.bytes_set += 1
}

put_word_to_info :: proc(word: u16) {
  assert(instr_state.info.bytes_set == 0)
  instr_state.info.data.word = word
  instr_state.info.bytes_set += 2
}

get_info_byte :: proc() -> u8 {
  assert(instr_state.info.bytes_set == 1)
  instr_state.info.bytes_set -= 1
  return instr_state.info.data.bytes.lsb
}

pop_info_byte :: proc() -> u8 {
  assert(instr_state.info.bytes_set > 0)
  if instr_state.info.bytes_set == 2 { instr_state.info.bytes_set -= 1; return instr_state.info.data.bytes.msb }
  if instr_state.info.bytes_set == 1 { instr_state.info.bytes_set -= 1; return instr_state.info.data.bytes.lsb }
  panic("Unreachable")
}

get_info_word :: proc() -> u16 {
  assert(instr_state.info.bytes_set == 2)
  instr_state.info.bytes_set -= 2
  return instr_state.info.data.word
}

get_param :: proc(type: Op_Param_Type, op: Opcode) -> u8 {
  for param in op.params {
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

