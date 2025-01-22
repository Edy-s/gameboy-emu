package main

do_alu :: proc(command: Command, instruction: Instruction) -> (bool, int) {
  valid       := false
  cycles_used := 0
  action := command.data.(Alu_Action)
  if running_opcode_info.bytes_set == 0 { // Non data functions
    #partial switch action.function {
      case .SCF:
        clear_flag(.Negative)
        clear_flag(.Half_Carry)
        set_flag(.Carry)
        
        valid = true
      case .CCF:
        clear_flag(.Negative)
        clear_flag(.Half_Carry)
        do_flag(.Carry, !get_flag(.Carry))
        
        valid = true
    }
  }
  if running_opcode_info.bytes_set == 1 { // Byte
    lhs := get_info_byte()
    rhs := action.has_rhs ? get_stash_byte() : 0
    
    result: u8
    carries: [8]bool
    
    #partial switch action.function {
    case .DAA:
      if get_flag(.Negative) {
        adj :u8= 0
        adj += get_flag(.Half_Carry) ? 0x06 : 0
        adj += get_flag(.Carry)      ? 0x60 : 0
        
        result, carries = real_subtraction(lhs, adj)
        // if (lhs != 0) && (adj > lhs) { set_flag(.Carry) } apparently, you don't ever set carry!
      } else {
        adj :u8= 0
        adj = (get_flag(.Half_Carry) || ((lhs & 0x0F) > 0x09)) ? 0x06 : 0
        lhs, carries = real_addition(lhs, adj)
        
        if carries[7] { set_flag(.Carry) }
        adj = 0
        adj += (get_flag(.Carry)     || ((lhs)        > 0x9F)) ? 0x60 : 0
        result, carries = real_addition(lhs, adj)
        
        if carries[7] { set_flag(.Carry) }
      }
      
      do_flag(.Zero, result == 0)
      clear_flag(.Half_Carry)
      
      valid = true
      
    case .AND:
      result = lhs & rhs
      
      do_flag(.Zero, result == 0)
      clear_flag(.Negative)
      set_flag(.Half_Carry)
      clear_flag(.Carry)
      
      valid = true
    case .OR:
      result = lhs | rhs
      
      do_flag(.Zero, result == 0)
      clear_flag(.Negative)
      clear_flag(.Half_Carry)
      clear_flag(.Carry)
      
      valid = true
    case .XOR:
      result = lhs ~ rhs
      
      do_flag(.Zero, result == 0)
      clear_flag(.Negative)
      clear_flag(.Half_Carry)
      clear_flag(.Carry)
      
      valid = true
    case .CPL: // NOT
      result = ~lhs
      
      set_flag(.Negative)
      set_flag(.Half_Carry)
      
      valid = true
      
    case .INC:
      result, carries = real_addition(lhs, 1)
      
      do_flag(.Zero, result == 0)
      clear_flag(.Negative)
      do_flag(.Half_Carry, carries[3])
      
      valid = true
    case .DEC:
      result, carries = real_subtraction(lhs, 1)
      
      do_flag(.Zero, result == 0)
      set_flag(.Negative)
      do_flag(.Half_Carry, carries[3])
      
      valid = true
      
    case .ADD:
      result, carries = real_addition(lhs, rhs)
      
      do_flag(.Zero, result == 0)
      clear_flag(.Negative)
      do_flag(.Half_Carry, carries[3])
      do_flag(.Carry, carries[7])
      
      valid = true
    case .ADC:
      result, carries = real_addition(lhs, rhs, pre_carry = get_flag(.Carry))
      
      do_flag(.Zero, result == 0)
      clear_flag(.Negative)
      do_flag(.Half_Carry, carries[3])
      do_flag(.Carry, carries[7])
      
      valid = true
    case .SUB:
      result, carries = real_subtraction(lhs, rhs)
      
      do_flag(.Zero, result == 0)
      set_flag(.Negative)
      do_flag(.Half_Carry, carries[3])
      do_flag(.Carry, carries[7])
      
      valid = true
    case .SBC:
      result, carries = real_subtraction(lhs, rhs, pre_borrow = get_flag(.Carry))
      
      do_flag(.Zero, result == 0)
      set_flag(.Negative)
      do_flag(.Half_Carry, carries[3])
      do_flag(.Carry, carries[7])
      
      valid = true
    case .CP:
      result, carries = real_subtraction(lhs, rhs)
      
      do_flag(.Zero, result == 0)
      set_flag(.Negative)
      do_flag(.Half_Carry, carries[3])
      do_flag(.Carry, carries[7])

      result = lhs
      
      valid = true
    
    case .SLA:
      do_flag(.Carry, (lhs & 0x80) != 0)
      result = lhs << 1
      
      do_flag(.Zero, result == 0)
      clear_flag(.Negative)
      clear_flag(.Half_Carry)
      
      valid = true
    case .SRA:
      do_flag(.Carry, (lhs & 0x01) != 0)
      high_bit := lhs & 0x80
      result = (lhs >> 1) | high_bit
      
      do_flag(.Zero, result == 0)
      clear_flag(.Negative)
      clear_flag(.Half_Carry)
      
      valid = true
    case .SRL:
      do_flag(.Carry, (lhs & 1) == 1)
      result = lhs >> 1
      do_flag(.Zero, result == 0)
      clear_flag(.Negative)
      clear_flag(.Half_Carry)
      
      valid = true
    case .RR:
      prev_carry := get_flag(.Carry)
      do_flag(.Carry, (lhs & 1) == 1)
      result = lhs >> 1
      if prev_carry { result |= 0x80 }
      
      do_flag(.Zero, result == 0)
      clear_flag(.Negative)
      clear_flag(.Half_Carry)
      if !action.set_flags { clear_flag(.Zero) }
      
      valid = true
    case .RL:
      prev_carry := get_flag(.Carry)
      do_flag(.Carry, (lhs & 0x80) != 0)
      result = lhs << 1
      if prev_carry { result |= 0x01 }
      
      do_flag(.Zero, result == 0)
      clear_flag(.Negative)
      clear_flag(.Half_Carry)
      if !action.set_flags { clear_flag(.Zero) }
      
      valid = true
    case .RRC:
      will_carry := (lhs & 0x01) != 0
      result = lhs >> 1
      result |= will_carry ? 0x80 : 0
      
      do_flag(.Zero, result == 0)
      clear_flag(.Negative)
      clear_flag(.Half_Carry)
      do_flag(.Carry, will_carry)
      if !action.set_flags { clear_flag(.Zero) }
      
      
      valid = true
    case .RLC:
      will_carry := (lhs & 0x80) != 0
      result = lhs << 1
      result |= will_carry ? 1 : 0
      
      do_flag(.Zero, result == 0)
      clear_flag(.Negative)
      clear_flag(.Half_Carry)
      do_flag(.Carry, will_carry)
      if !action.set_flags { clear_flag(.Zero) }
      
      valid = true
    
    case .SWAP:
      result = (lhs >> 4) | (lhs << 4)
      
      do_flag(.Zero, result == 0)
      clear_flag(.Negative)
      clear_flag(.Half_Carry)
      clear_flag(.Carry)
      
      valid = true
      
    case .BIT:
      bit_index := get_param(.bi3, instruction)
      mask := u8(1) << bit_index
      result = lhs & mask
      
      do_flag(.Zero, result == 0)
      clear_flag(.Negative)
      set_flag(.Half_Carry)
      
      valid = true
    case .RES:
      bit_index := get_param(.bi3, instruction)
      mask := u8(1) << bit_index
      result = lhs & ~mask
      
      valid = true
    case .SET:
      bit_index := get_param(.bi3, instruction)
      mask := u8(1) << bit_index
      result = lhs | mask
      
      valid = true
      
    }
    put_byte_to_info(result)
    
  } else if running_opcode_info.bytes_set == 2 { // Word
    lhs := get_info_word()
    
    #partial switch action.function {
    case .SIGNED_ADD:
      assert(action.has_rhs)
      rhs := u16(i16(i8(get_stash_byte())))
      
      result := lhs + rhs
      
      if action.set_flags {
        clear_flag(.Zero)
        clear_flag(.Negative)
        _, carries := real_addition(u8(lhs), u8(rhs))
        do_flag(.Half_Carry, carries[3])
        do_flag(.Carry, carries[7])
      }
      
      put_word_to_info(result)
      
      cycles_used += 1
      valid = true
      
    case .ADD:
      assert(action.has_rhs)
      rhs := get_stash_word()
      small_rhs := u8(rhs & 0xFF)
      lsb, lsc := real_addition(u8(lhs), small_rhs)
      msb, carries := real_addition(u8(lhs >> 8), u8(rhs >> 8), pre_carry = lsc[7])
      
      result := (u16(msb) << 8) | u16(lsb)
      
      clear_flag(.Negative)
      do_flag(.Half_Carry, carries[3])
      do_flag(.Carry, carries[7])
      
      put_word_to_info(result)
      
      cycles_used += 1
      valid = true
      
    case .INC:
      lhs += 1
      put_word_to_info(lhs)
      
      cycles_used += 1
      valid = true
    case .DEC:
      lhs -= 1
      put_word_to_info(lhs)
      
      cycles_used += 1
      valid = true
    }
  }
  return valid, cycles_used
}


real_addition :: proc(A, B: u8, pre_carry := false) -> (result: u8, carries: [8]bool) {
  carry := pre_carry
  for i in 0..<8 {
    mask := u8(1) << u8(i)
    
    after_carry := carry ? (~B & mask) : (B & mask)
    
    result |=  (A & mask) ~ after_carry
    carry   = ((A & mask) & after_carry) != 0 || (carry && ((B & mask) != 0))
    
    if carry { carries[i] = true }
  }
  
  return result, carries
}

real_subtraction :: proc(A, B: u8, pre_borrow := false) -> (result: u8, carries: [8]bool) {
  borrow := pre_borrow
  for i in 0..<8 {
    mask := u8(1) << u8(i)
    
    after_borrow := borrow ? (~B & mask) : (B & mask)
    
    result |=   (A & mask) ~ after_borrow
    borrow  = ((~A & mask) & after_borrow) != 0 || (borrow && ((B & mask) != 0))
    
    if borrow { carries[i] = true }
  }
  
  return result, carries
}
