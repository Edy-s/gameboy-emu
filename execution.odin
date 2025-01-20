#+private file
package main

@(private)
execute_instruction :: proc(source_instruction: Instruction) -> bool {
  instruction := source_instruction
  success := true
  
  if instruction.op != .nop {
    if !print_instruction_on_fail_only do pretty_print_instruction(instruction)
    
    assert(instruction.op != .illegal)
    
    dest_term   := &instruction.dest_term
    source_term := &instruction.source_term
    
    #partial switch instruction.op {
    case .jmp:
      Jump_Condition :: enum u8 { NOT_SET, nz, z, nc, c }
      condition: Jump_Condition
      if .cond in instruction.set_params {
        condition = Jump_Condition(instruction.params[.cond] + 1)
        instruction.set_params -= {.cond}
        instruction.params[.cond] = 0
      }
      
      condition_met := false
      switch condition {
      case .nz:
        flag := get_flag(.Zero)
        condition_met = (flag == 0)
      case .z:
        flag := get_flag(.Zero)
        condition_met = (flag != 0)
      case .nc:
        flag := get_flag(.Carry)
        condition_met = (flag == 0)
      case .c:
        flag := get_flag(.Carry)
        condition_met = (flag != 0)
      case .NOT_SET:
        condition_met = true
      }
      
      if condition_met {
        if .jmp_delta in instruction.modifiers {
          if source_term.type == .imm8 {
            change_value : u16 = u16(i16(i8(source_term.value8)))
            
            instruction_pointer += change_value
            
            source_term^ = {}
            instruction.modifiers -= {.jmp_delta}
          }
        } else {
          if source_term.type == .imm16 {
            instruction_pointer = source_term.value16
            source_term^ = {}
          }
        }
      } else {
        source_term^ = {}
        instruction.modifiers -= {.jmp_delta}
      }
      
      instruction.op = Operators(0)
      
    case .ld:
      source_value_8:     u8
      source_value_8_set: bool
      source_value_16:     u16
      source_value_16_set: bool
      
      times_mem_hl_was_seen := 0
      
      // TODO: do proper logging with categories
      // print("Loaded from")
      
      if source_term.type != .NOT_SET {
        #partial switch source_term.type {
        case .a:
          source_value_8 = registers.byte[.A]
          source_value_8_set = true
          
          // print(" reg_a: %v", registers[.A])
          source_term^ = {}
        case .imm8:
          source_value_8 = source_term.value8
          source_value_8_set = true
          
          // print(" imm8: %v", source_term.value8)
          source_term^ = {}
        case .imm16:
          source_value_16 = source_term.value16
          source_value_16_set = true
          
          // print(" imm16: %v", source_term.value16)
          source_term^ = {}
        case .r8:
          if source_term.value8 == 6 { times_mem_hl_was_seen += 1}
          source_value_8 = r8_to_byte(source_term.value8)^
          source_value_8_set = true
          
          // print(" r8: %v", source_term.value8)
          source_term^ = {}
        case .r16mem:
          if source_term.value8 == 2 || source_term.value8 == 3 {
            address := regs_word[.HL]
            source_value_8 = memory_map[address]
            source_value_8_set = true
            
            if source_term.value8 == 2 { address += 1 }
            else                       { address -= 1 }
            regs_word[.HL] = address
            
            // print(" r16mem: %v", source_value_8)
            source_term^ = {}
          }
        }
      }
      
      // print(" into")
      
      if dest_term.type != .NOT_SET {
        {
          byte_destinations : bit_set[Op_Param_Type] = {.a, .r8, .r16mem, .imm8_addr, .imm16_addr}
          word_destinations : bit_set[Op_Param_Type] = {.r16}
          if dest_term.type in byte_destinations {
            assert(source_value_8_set, "Trying to put a 8-bit value into 8-bit register, but 8-bit value was not set.")
          }
          if dest_term.type in word_destinations {
            assert(source_value_16_set, "Trying to put a 16-bit value into 16-bit register, but 16-bit value was not set.")
          } 
        }
        
        #partial switch dest_term.type {
        case .a:
          regs_byte[.A] = source_value_8
          
          // print(" reg_a")
          dest_term^ = {}
          
        case .r16:
          fat_reg := r16_mapping[dest_term.value8]
          regs_word[fat_reg] = source_value_16
          
          // print(" r16: %v", fat_reg)
          dest_term^ = {}
          
        case .r8:
          if dest_term.value8 == 6 { times_mem_hl_was_seen += 1}
          dest_byte := r8_to_byte(dest_term.value8)
          dest_byte^ = source_value_8
          
          // print(" r8: %v", dest_term.value8)
          dest_term^ = {}
          
        case .r16mem:
          if dest_term.value8 == 2 || dest_term.value8 == 3 {
            address := regs_word[.HL]
            memory_map[address] = source_value_8
            
            if dest_term.value8 == 2 { address += 1 }
            else                     { address -= 1 }
            regs_word[.HL] = address
            
            // print(" r16mem: HL")
            dest_term^ = {}
          } else {
            fat_reg := r16_mapping[dest_term.value8]
            address := regs_word[fat_reg]
            
            memory_map[address] = source_value_8
            
            // print(" r16mem: %v", fat_reg)
            dest_term^ = {}
          }
          
        case .imm16_addr:
          address := dest_term.value16
          memory_map[address] = source_value_8
          
          dest_term^ = {}
          
        case .imm8_addr:
          address := 0xFF00 + u16(dest_term.value8)
          memory_map[address] = source_value_8
          
          dest_term^ = {}
        }
      }
      
      // print("\n\n")
      
      assert(times_mem_hl_was_seen != 2, "We got to the point of trying to do ld [hl], [hl] , but this should instead be a halt instruction.")
      instruction.op = Operators(0)
      
    case .inc:
      assert(dest_term.type != .NOT_SET)
      #partial switch dest_term.type {
      case .r8:
        target_byte := r8_to_byte(dest_term.value8)
        target_byte^ += 1
        
        is_zero := (target_byte^ == 0)
        do_flag(.Zero, is_zero)
        
        clear_flag(.Negative)
        
        // Lower 4 bits overflow.
        is_overflow := ((target_byte^ & 0xF) == 0)
        do_flag(.Half_Carry, is_overflow)
        
        dest_term^ = {}
        
      case .r16:
        target_reg := r16_mapping[dest_term.value8]
        regs_word[target_reg] += 1
        
        dest_term^ = {}
      }
      instruction.op = Operators(0)
    
    case .dec:
      assert(dest_term.type != .NOT_SET)
      #partial switch dest_term.type {
      case .r8:
        target_byte := r8_to_byte(dest_term.value8)
        target_byte^ -= 1
        
        is_zero := (target_byte^ == 0)
        do_flag(.Zero, is_zero)
        
        set_flag(.Negative)
        
        // Lower 4 bits underflow.
        is_underflow := (((target_byte^ & 0xF) ~ 0xF) == 0)
        do_flag(.Half_Carry, is_underflow)
        
        dest_term^ = {}
      }
      instruction.op = Operators(0)
    
    // case .or:
    //   assert(source_term.type != .NOT_SET)
    //   source_value: u8
    //   if source_term.type == .r8 {
    //     source_value = r8_to_byte(source_term.value8)^
    //     source_term^ = {}
    //   }
      
      
        
    // case .ei:
    //   interrupt_master_flag = 1
    //   instruction.op = Operators(0)
      
    case .di:
      interrupt_master_flag = 0
      instruction.op = Operators(0)
    
    case .call:
      assert(source_term.type == .imm16)
    
      stack_pointer := &regs_word[.SP]
      stack_pointer^ -= 1
      memory_map[stack_pointer^] = u8(instruction_pointer >> 8)
      stack_pointer^ -= 1
      memory_map[stack_pointer^] = u8(instruction_pointer & 0xFF)
      
      instruction_pointer = source_term.value16
      
      source_term^ = {}
      instruction.op = Operators(0)
    
    case .ret:
      stack_pointer := &regs_word[.SP]
      lo_byte := memory_map[stack_pointer^]
      stack_pointer^ += 1
      hi_byte := memory_map[stack_pointer^]
      stack_pointer^ += 1
      
      instruction_pointer = u16(hi_byte) << 8 | u16(lo_byte)
      
      instruction.op = Operators(0)
      
    case .push:
      assert(source_term.type == .r16stk)
      
      source_reg := r16stk_mapping[source_term.value8]
      hi_reg, lo_reg := word_to_byte_registers(source_reg)
      hi_byte, lo_byte := regs_byte[hi_reg], regs_byte[lo_reg]
      
      stack_pointer := &regs_word[.SP]
      stack_pointer^ -= 1
      memory_map[stack_pointer^] = hi_byte
      stack_pointer^ -= 1
      memory_map[stack_pointer^] = lo_byte
      
      source_term^ = {}
      instruction.op = Operators(0)
    
    case .pop:
      assert(source_term.type == .r16stk)
      
      stack_pointer := &regs_word[.SP]
      lo_byte := memory_map[stack_pointer^]
      stack_pointer^ += 1
      hi_byte := memory_map[stack_pointer^]
      stack_pointer^ += 1
      
      target_reg := r16stk_mapping[source_term.value8]
      hi_reg, lo_reg := word_to_byte_registers(target_reg)
      regs_byte[hi_reg], regs_byte[lo_reg] = hi_byte, lo_byte
      
      source_term^ = {}
      instruction.op = Operators(0)
    }
    
    if instruction != {} {
      print("Instruction not implemented!\n")
      success = false
    }
  }
    
  return success
}


r16_mapping :=    [?]Reg_16bit{.BC, .DE, .HL, .SP}
r16stk_mapping := [?]Reg_16bit{.BC, .DE, .HL, .AF}

word_to_byte_registers :: proc(word_reg: Reg_16bit) -> (hi, lo: Reg_8bit) {
  hi = Reg_8bit(u8(word_reg) * 2 + 1)
  lo = Reg_8bit(u8(word_reg) * 2)
  
  return
}

r8_to_byte :: proc(r8_val: u8) -> ^u8 {
  result: ^u8
  r8_to_register_mapping := [?]Reg_8bit{.B, .C, .D, .E, .H, .L, .F, .A}
  
  assert(r8_val < len(r8_to_register_mapping), "Illegal r8 value passed.")
  
  if r8_val != 6 {
    result = &regs_byte[r8_to_register_mapping[r8_val]]
  } else {
    // Maybe shouldn't handle the [hl] case here
    address := regs_word[.HL]
    result = &memory_map[address]
  }
  
  return result
}

get_flag :: proc(flag: Flags) -> u8 {
  flag_byte := regs_byte[.F]
  flag_bit := flag_byte & u8(flag)
  return flag_bit
}

do_flag :: proc(flag: Flags, set: bool) {
  if set {
    set_flag(flag)
  } else {
    clear_flag(flag)
  }
}

set_flag :: proc(flag: Flags) {
  flag_byte := &regs_byte[.F]
  flag_byte^ |= u8(flag)
}

clear_flag :: proc(flag: Flags) {
  flag_byte := &regs_byte[.F]
  flag_byte^ &= ~u8(flag)
}