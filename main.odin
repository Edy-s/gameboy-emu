package main

import "core:os"
import "core:fmt"

Registers :: enum {
  A, F, B, C, D, E, H, L
}
Fat_Registers :: enum {
  AF, BC, DE, HL
}
Flags :: enum u8 {
  Zero       = 0x1,
  Negative   = 0x2,
  Half_Carry = 0x4,
  Carry      = 0x8,
}

registers : [Registers]u8
stack_pointer : u16
instruction_pointer :u16= 0x100

main_ram : [0xFFFFF]u8

number_of_instructions_executed_succesfully := 0

main :: proc() {
  file, ok := os.read_entire_file_from_filename("D:/codes/gameboy_emulator/gb-test-roms/cpu_instrs/individual/09-op r,r.gb")
  if !ok {
    fmt.printf("Couldn't read file\n")
    return
  }
  
  nopsed := 0
  
  prefixed := false
  running := true
  
  for running {
    found := false
    
    table := !prefixed ? opcode_table[:] : opcode_table_prefixed[:]
    instruction : Instruction
    
    for opcode, i in table {
      temp_ip := instruction_pointer
      current_byte := file[temp_ip]
      
      bit_offset :u16= 8
      valid := true
      
      instruction = {}
      instruction.op = opcode.op
      instruction.modifiers = opcode.modifiers
      
      for encoding_union in opcode.encodings {
        switch encoding in encoding_union {
        case Bit_Pattern:
          bit_offset -= encoding.bit_count
          extracted_bits := current_byte >> bit_offset & ((1 << encoding.bit_count) - 1)
        
          comparison_result := encoding.value ~ extracted_bits
          if comparison_result != 0 {
            valid = false
          }
        
        case Op_Param:
          bit_count := Op_Param_Type_Sizes[encoding.type]
          bit_offset -= u16(bit_count)
          extracted_bits := current_byte >> bit_offset & ((1 << bit_count) - 1)
          
          #partial switch encoding.term {
          case .none:
            instruction.set_params |= {encoding.type}
            instruction.params[encoding.type] = extracted_bits
          case:
            instruction.terms[encoding.term].type   = encoding.type
            instruction.terms[encoding.term].value8 = extracted_bits
          }
          
          if encoding.type == .imm8 {
            assert(bit_offset == 0, "Immediate encoding before all bits were extracted!\n")
            temp_ip += 1
            instruction.terms[encoding.term].value8 = file[temp_ip]
          }
          if encoding.type == .imm16 {
            assert(bit_offset == 0, "Immediate encoding before all bits were extracted!\n")
            temp_ip += 2
            instruction.terms[encoding.term].value16 = (u16(file[temp_ip]) << 8) | (u16(file[temp_ip-1]))
          }
        }
        
        if !valid { break }
      }
      
      if valid && bit_offset != 0 {
        fmt.printf("Op: %v, idx: %v, bit_of: %v\n", instruction.op, i, bit_offset)
        
        panic("Bad instruction encoding; non-zero bit offset.\n")
      }
      
      if valid {
        found = true
        temp_ip += 1
        
        prev_ip := instruction_pointer // temp variable for printing
        instruction_pointer = temp_ip
        
        if instruction.op == .prefix {
          prefixed = true
          break
        }
        
        if instruction.op == .nop {
          nopsed += 1
        } else {
          if nopsed != 0 {
            fmt.printf("Op: nop x%v\n", nopsed)
            nopsed = 0
          }
          
          fmt.printf("Op: %v, 0x: %2x, 0b: %8b, at: %d", instruction.op, file[prev_ip], file[prev_ip], prev_ip)
          if prefixed {
            fmt.printf(" prefixed!")
            prefixed = false
          }
          fmt.println()
        }
        
        
        break
      }
    }
    
    if !found {
      fmt.printf("No instruction found! Byte of note: %8b / %2x, at %x\n", file[instruction_pointer], file[instruction_pointer], instruction_pointer)
      break
    }
    
    if instruction.op != .nop {
      assert(instruction.op != .illegal)
      
      fmt.printf("%v\n\n", instruction)
      unmodified_instruction := instruction
      
      dest_term   := &instruction.terms[.dest]
      source_term := &instruction.terms[.source]
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
        
        if source_term.type != .NOT_SET {
          #partial switch source_term.type {
          case .a:
            source_value_8 = registers[.A]
            source_value_8_set = true
            source_term^ = {}
          case .imm8:
            source_value_8 = source_term.value8
            source_value_8_set = true
            source_term^ = {}
          case .imm16:
            source_value_16 = source_term.value16
            source_value_16_set = true
            source_term^ = {}
          case .r8:
            if source_term.value8 == 6 { times_mem_hl_was_seen += 1}
            source_value_8 = r8_to_byte(source_term.value8)^
            source_value_8_set = true
            source_term^ = {}
          case .r16mem:
            if source_term.value8 == 2 || source_term.value8 == 3 {
              address := fat_register_value(.HL)
              source_value_8 = main_ram[address]
              source_value_8_set = true
              
              if source_term.value8 == 2 { address += 1 }
              else                       { address -= 1 }
              put_u16_to_fat_register(.HL, address)
              
              source_term^ = {}
            }
          }
        }
        
        if dest_term.type != .NOT_SET {
          #partial switch dest_term.type {
          case .a:
            assert(source_value_8_set, "Trying to put a 8-bit value into 8-bit register, but 8-bit value was not set.")
            
            registers[.A] = source_value_8
            
            dest_term^ = {}
          case .r16:
            assert(source_value_16_set, "Trying to put a 16-bit value into 16-bit register, but 16-bit value was not set.")
            
            fat_reg := r16_to_fat_register(dest_term.value8)
            put_u16_to_fat_register(fat_reg, source_value_16)
            
            dest_term^ = {}
          case .r8:
            assert(source_value_8_set, "Trying to put a 8-bit value into 8-bit register, but 8-bit value was not set.")
            if dest_term.value8 == 6 { times_mem_hl_was_seen += 1}
            dest_byte := r8_to_byte(dest_term.value8)
            dest_byte^ = source_value_8
            
            dest_term^ = {}
          case .r16mem:
            assert(source_value_8_set, "Trying to put a 8-bit value into 8-bit register, but 8-bit value was not set.")
            if dest_term.value8 == 2 || dest_term.value8 == 3 {
              address := fat_register_value(.HL)
              main_ram[address] = source_value_8
              
              if dest_term.value8 == 2 { address += 1 }
              else                     { address -= 1 }
              put_u16_to_fat_register(.HL, address)
              
              dest_term^ = {}
            } else {
              fat_reg := r16_to_fat_register(source_term.value8)
              address := fat_register_value(fat_reg)
              
              main_ram[address] = source_value_8
              
              dest_term^ = {}
            }
          }
        }
        
        assert(times_mem_hl_was_seen != 2, "We got to the point of trying to do ld [hl], [hl] , but this should instead be a halt instruction.")
        instruction.op = Operators(0)
        
      case .inc:
        assert(dest_term.type != .NOT_SET)
        #partial switch dest_term.type {
        case .r8:
          target_byte := r8_to_byte(dest_term.value8)
          target_byte^ += 1
          
          if target_byte^ == 0 { set_flag(.Zero) }
          clear_flag(.Negative)
          if (target_byte^ & 0xF) == 0 {
            // Lower 4 bits overflow
            set_flag(.Half_Carry)
          }
          
          dest_term^ = {}
        }
        instruction.op = Operators(0)
        
      case:
      }
      
      if instruction != {} {
        fmt.printf("Instruction not implemented!\n")
        fmt.printf("Number of instructions executed: %v\n", number_of_instructions_executed_succesfully)
        running = false
      }
      
      number_of_instructions_executed_succesfully += 1
    }
  }
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
    fmt.printf("Questionable if this should happen!\n")
  case:
    panic("Illegal r16 value.")
  }
  
  return
}

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
  
  left_reg^  = u8(value & 0xFF)
  right_reg^ = u8((value & 0xFF00) >> 8)
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
    result = &main_ram[address]
  }
  
  return result
}

get_flag :: proc(flag: Flags) -> u8 {
  flag_byte := registers[.F]
  flag_bit := flag_byte & u8(flag)
  return flag_bit
}

set_flag :: proc(flag: Flags) {
  flag_byte := &registers[.F]
  flag_byte^ |= u8(flag)
}

clear_flag :: proc(flag: Flags) {
  flag_byte := &registers[.F]
  flag_byte^ &= ~u8(flag)
}