package main

nopsed := 0

decode_next :: proc(prefixed: bool) -> (result: Opcode, commands: []Command) {
  instruction_byte := read_at(regs.word[.PC])
  found := false
  
  table := !prefixed ? opcode_table_v2[:] : opcode_table_prefixed_v2[:]
  
  for encoding in table {
    opcode := encoding.opcode
    if ((instruction_byte & opcode.mask) ~ opcode.value) == 0 {
      found = true
      
      result.opcode_string  = encoding.opcode_string
      result.reference_byte = instruction_byte
      result.timing.min = encoding.timing.min
      result.timing.max = encoding.timing.max
      for &param, i in result.params {
        param.type  = opcode.params[i].type
        param.value = (instruction_byte & opcode.params[i].mask) >> opcode.params[i].r_offset
      }
      
      commands = encoding.commands[:]
      assert(len(commands) != 0)
      
      break
    }
  }
  
  if found {
    regs.word[.PC] += 1
  } else {
    print("No instruction found!!! Byte of note: %8b / %2x, at %x\n", instruction_byte, instruction_byte, regs.word[.PC])
    panic("We should always find an instruction.")
  }
  
  
  return result, commands
}