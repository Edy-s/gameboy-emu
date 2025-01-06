package main

import "core:os"
import "core:fmt"

main :: proc() {
  file, ok := os.read_entire_file_from_filename("D:/codes/gameboy_emulator/gb-test-roms/cpu_instrs/individual/09-op r,r.gb")
  if !ok {
    fmt.printf("Couldn't read file\n")
    return
  }
  
  nopsed := 0
  instruction_pointer := 0x100
  prefixed := false
  
  for true {
    // fmt.printf("%x\n", file[instruction_pointer])
    
    found := false
    
    table : []Op_Encoding
    if !prefixed {
      table = opcode_table[:]
    } else {
      table = opcode_table_prefixed[:]
      // prefixed = false
    }
    
    for opcode, i in table {
      temp_ip := instruction_pointer
      current_byte := file[temp_ip]
      
      bit_offset :u16= 8
      valid := true
      
      instruction : Instruction
      instruction.op = opcode.op
      
      for encoding_union in opcode.encodings {
        switch encoding in encoding_union {
        case Bit_Pattern:
          bit_offset -= encoding.bit_count
          extracted_bits := current_byte >> bit_offset & ((1 << encoding.bit_count) - 1)
        
          comparison_result := encoding.value ~ extracted_bits
          if comparison_result != 0 {
            valid = false
            break
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
            instruction.terms[encoding.term].value16 = (u16(file[temp_ip]) << 8) | (u16(file[temp_ip]))
          }
        }
      }
      
      if bit_offset != 0 {
        fmt.printf("Op: %v, idx: %v, bit_of: %v\n", instruction.op, i, bit_offset)
        
        panic("Bad instruction encoding.\n")
      }
      
      if valid {
        found = true
        temp_ip += 1
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
          
          fmt.printf("Op: %v", instruction.op)
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
  }
}