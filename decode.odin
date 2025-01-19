#+private file
package main

nopsed := 0

@(private)
decode_next_instruction :: proc() -> Instruction {
  prev_ip := instruction_pointer // temp variable for printing
  prefixed := false
  
  instruction, found := match_opcode(opcode_table[:])
  
  if found && instruction.op == .prefix {
    prefixed = true
    instruction, found = match_opcode(opcode_table_prefixed[:])
  }
    
  if found {
    if instruction.op == .nop {
      nopsed += 1
    } else {
      if nopsed != 0 {
        print("NOPs encountered: %v\n", nopsed)
        nopsed = 0
      }
      
      print("Op: %v, 0x: %2x, 0b: %8b, at: %d", instruction.op, memory_map[prev_ip], memory_map[prev_ip], prev_ip)
      if prefixed {
        print(" prefixed!")
      }
      print("\n")
    }
  }
  
  if !found {
    print("No instruction found! Byte of note: %8b / %2x, at %x\n", memory_map[instruction_pointer], memory_map[instruction_pointer], instruction_pointer)
    panic("We should in practice always find an instruction.")
  }
  
  return instruction
}

match_opcode :: proc(op_table: []Op_Encoding) -> (Instruction, bool) {
  instruction : Instruction
  found := false
  
  for opcode, i in op_table {
    temp_ip := instruction_pointer
    current_byte := memory_map[temp_ip]
    
    bit_offset :u16= 8
    bit_pattern_matches := true
    
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
          bit_pattern_matches = false
        }
      
      case Op_Param:
        bit_count := Op_Param_Type_Sizes[encoding.type]
        bit_offset -= u16(bit_count)
        extracted_bits := current_byte >> bit_offset & ((1 << bit_count) - 1)
        
        instr_term: ^Term
        switch encoding.term {
        case .dest:
          instr_term = &instruction.dest_term
        case .source:
          instr_term = &instruction.source_term
        case .none:
        }
        
        #partial switch encoding.term {
        case .none:
          instruction.set_params |= {encoding.type}
          instruction.params[encoding.type] = extracted_bits
        case:
          instr_term.type   = encoding.type
          instr_term.value8 = extracted_bits
        }
        
        if encoding.type == .imm8 || encoding.type == .imm8_addr {
          assert(bit_offset == 0, "Immediate encoding before all bits were extracted!\n")
          temp_ip += 1
          instr_term.value8 = memory_map[temp_ip]
        }
        if encoding.type == .imm16 || encoding.type == .imm16_addr {
          assert(bit_offset == 0, "Immediate encoding before all bits were extracted!\n")
          temp_ip += 2
          instr_term.value16 = (u16(memory_map[temp_ip]) << 8) | (u16(memory_map[temp_ip-1]))
        }
      }
      
      if !bit_pattern_matches { break }
    }
    
    if bit_pattern_matches && bit_offset != 0 {
      print("Op: %v, idx: %v, bit_of: %v\n", instruction.op, i, bit_offset)
      
      panic("Bad instruction encoding; non-zero bit offset.\n")
    }
    
    if bit_pattern_matches { 
      found = true
      
      temp_ip += 1
      instruction_pointer = temp_ip
      
      break
    }
  }
  
  return instruction, found
}