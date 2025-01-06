package main

import "core:os"
import "core:fmt"

main :: proc() {
  file, ok := os.read_entire_file_from_filename("D:/codes/gameboy_emulator/gb-test-roms/cpu_instrs/individual/09-op r,r.gb")
  if !ok {
    fmt.printf("Couldn't read file\n")
    return
  }
  
  
  instruction_pointer := 0x150
  
  for true {
    // fmt.printf("%x\n", file[instruction_pointer])
    
    found := false
    for opcode, i in opcode_table {
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
            temp_ip += 1
            instruction.terms[encoding.term].value8 = file[temp_ip]
          }
          if encoding.type == .imm16 {
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
        
        fmt.printf("Op: %v\n", instruction.op)
        break
      }
    }
  }
}