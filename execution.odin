#+private file
package main

@(private)
execute_instruction :: proc(instruction: Instruction) -> bool {
  instruction := instruction
  success := true
  
  if instruction.op != .nop {
    if !print_instruction_on_fail_only do pretty_print_instruction(instruction)
    
    assert(instruction.op != .illegal)
    unmodified_instruction := instruction
    
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
            change_value : u16 = transmute(u16)(i16(transmute(i8)source_term.value8))
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
          source_value_8 = registers[.A]
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
            address := fat_register_value(.HL)
            source_value_8 = memory_map[address]
            source_value_8_set = true
            
            if source_term.value8 == 2 { address += 1 }
            else                       { address -= 1 }
            put_u16_to_fat_register(.HL, address)
            
            // print(" r16mem: %v", source_value_8)
            source_term^ = {}
          }
        }
      }
      
      // print(" into")
      
      if dest_term.type != .NOT_SET {
        #partial switch dest_term.type {
        case .a:
          assert(source_value_8_set, "Trying to put a 8-bit value into 8-bit register, but 8-bit value was not set.")
          
          registers[.A] = source_value_8
          
          // print(" reg_a")
          dest_term^ = {}
        case .r16:
          assert(source_value_16_set, "Trying to put a 16-bit value into 16-bit register, but 16-bit value was not set.")
          
          fat_reg := r16_to_fat_register(dest_term.value8)
          put_u16_to_fat_register(fat_reg, source_value_16)
          
          // print(" r16: %v", fat_reg)
          dest_term^ = {}
        case .r8:
          assert(source_value_8_set, "Trying to put a 8-bit value into 8-bit register, but 8-bit value was not set.")
          if dest_term.value8 == 6 { times_mem_hl_was_seen += 1}
          dest_byte := r8_to_byte(dest_term.value8)
          dest_byte^ = source_value_8
          
          // print(" r8: %v", dest_term.value8)
          dest_term^ = {}
        case .r16mem:
          assert(source_value_8_set, "Trying to put a 8-bit value into 8-bit register, but 8-bit value was not set.")
          if dest_term.value8 == 2 || dest_term.value8 == 3 {
            address := fat_register_value(.HL)
            memory_map[address] = source_value_8
            
            if dest_term.value8 == 2 { address += 1 }
            else                     { address -= 1 }
            put_u16_to_fat_register(.HL, address)
            
            // print(" r16mem: HL")
            dest_term^ = {}
          } else {
            fat_reg := r16_to_fat_register(dest_term.value8)
            address := fat_register_value(fat_reg)
            
            memory_map[address] = source_value_8
            
            // print(" r16mem: %v", fat_reg)
            dest_term^ = {}
          }
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
      
    case:
    }
    
    if instruction != {} {
      print("Instruction not implemented!\n")
      success = false
    }
  }
    
  return success
}


r16_to_fat_register :: proc(r16_val: u8) -> (result: Fat_Registers) {
  switch r16_val {
  case 0:
    result = .BC
  case 1:
    result = .DE
  case 2:
    result = .HL
  case 3:
    result = .AF
    print("Questionable if this should happen!\n")
  case:
    panic("Illegal r16 value.")
  }
  
  return
}

@(private)
fat_register_value :: proc(fat_reg: Fat_Registers) -> u16 {
  l, r := fat_to_two_registers(fat_reg)
  left_reg, right_reg := registers[l], registers[r]
  
  result := (u16(left_reg) << 8) | u16(right_reg)
  
  return result
}

put_u16_to_fat_register :: proc(fat_reg: Fat_Registers, value: u16) {
  l, r := fat_to_two_registers(fat_reg)
  left_reg  := &registers[l]
  right_reg := &registers[r]
  
  left_reg^  = u8((value & 0xFF00) >> 8)
  right_reg^ = u8(value & 0xFF)
}

fat_to_two_registers :: proc(fat_reg: Fat_Registers) -> (left, right: Registers) {
  switch fat_reg {
  case .AF:
    left, right = .A, .F
  case .BC:
    left, right = .B, .C
  case .DE:
    left, right = .D, .E
  case .HL:
    left, right = .H, .L
  }
  return
}


r8_to_byte :: proc(r8_val: u8) -> ^u8 {
  result: ^u8
  r8_to_register_mapping := [?]Registers{.B, .C, .D, .E, .H, .L, .F, .A}
  
  assert(r8_val < len(r8_to_register_mapping), "Illegal r8 value passed.")
  
  if r8_val != 6 {
    result = &registers[r8_to_register_mapping[r8_val]]
  } else {
    // Maybe shouldn't handle the [hl] case here
    address := fat_register_value(.HL)
    result = &memory_map[address]
  }
  
  return result
}

get_flag :: proc(flag: Flags) -> u8 {
  flag_byte := registers[.F]
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
  flag_byte := &registers[.F]
  flag_byte^ |= u8(flag)
}

clear_flag :: proc(flag: Flags) {
  flag_byte := &registers[.F]
  flag_byte^ &= ~u8(flag)
}