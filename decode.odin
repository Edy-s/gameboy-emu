package main

nopsed := 0

command_buffer : [dynamic]Command
command_index  : int

Instruction_v2 :: struct {
  opcode_string: string,
  reference_byte: u8,
  params: [2]struct {
    type: Op_Param_Type2,
    value: u8,
  }
}

decode_next :: proc(prefixed: bool) -> (result: Instruction_v2) {
  assert(len(command_buffer) == 0)
  
  instruction_byte := memory_map[instruction_pointer]
  // instruction_byte := memory_map[regs_word[.PC]]
  found := false
  
  table := !prefixed ? opcode_table_v2[:] : opcode_table_prefixed_v2[:]
  
  for encoding in table {
    opcode := encoding.opcode
    if ((instruction_byte & opcode.mask) ~ opcode.value) == 0 {
      found = true
      
      result.opcode_string  = encoding.opcode_string
      result.reference_byte = instruction_byte
      for &param, i in result.params {
        param.type  = opcode.params[i].type
        param.value = (instruction_byte & opcode.params[i].mask) >> opcode.params[i].r_offset
      }
      
      command_index = 0
      for cmd in encoding.commands {
        append(&command_buffer, cmd)
      }
      
      break
    }
  }
  
  if found {
    //regs_word[.PC] += 1
  } else {
    print("No instruction found!!! Byte of note: %8b / %2x, at %x\n", instruction_byte, instruction_byte, regs_word[.PC])
    panic("We should in practice always find an instruction.")
  }
  
  return result
}