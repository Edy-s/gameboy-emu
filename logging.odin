package main

import "core:strings"

print_for_doc :: proc(sb: ^strings.Builder) {
  strings.write_string(sb, "A:")
  if regs.byte[.A] < 0x10 { strings.write_string(sb, "0") }
  strings.write_u64(sb, u64(regs.byte[.A]), 16)
  strings.write_string(sb, " F:")
  if regs.byte[.F] < 0x10 { strings.write_string(sb, "0") }
  strings.write_u64(sb, u64(regs.byte[.F]), 16)
  strings.write_string(sb, " B:")
  if regs.byte[.B] < 0x10 { strings.write_string(sb, "0") }
  strings.write_u64(sb, u64(regs.byte[.B]), 16)
  strings.write_string(sb, " C:")
  if regs.byte[.C] < 0x10 { strings.write_string(sb, "0") }
  strings.write_u64(sb, u64(regs.byte[.C]), 16)
  strings.write_string(sb, " D:")
  if regs.byte[.D] < 0x10 { strings.write_string(sb, "0") }
  strings.write_u64(sb, u64(regs.byte[.D]), 16)
  strings.write_string(sb, " E:")
  if regs.byte[.E] < 0x10 { strings.write_string(sb, "0") }
  strings.write_u64(sb, u64(regs.byte[.E]), 16)
  strings.write_string(sb, " H:")
  if regs.byte[.H] < 0x10 { strings.write_string(sb, "0") }
  strings.write_u64(sb, u64(regs.byte[.H]), 16)
  strings.write_string(sb, " L:")
  if regs.byte[.L] < 0x10 { strings.write_string(sb, "0") }
  strings.write_u64(sb, u64(regs.byte[.L]), 16)
  
  
  strings.write_string(sb, " SP:")
  if regs.word[.SP] < 0x10   { strings.write_string(sb, "0") }
  if regs.word[.SP] < 0x100  { strings.write_string(sb, "0") }
  if regs.word[.SP] < 0x1000 { strings.write_string(sb, "0") }
  strings.write_u64(sb, u64(regs.word[.SP]), 16)
  strings.write_string(sb, " PC:")
  if regs.word[.PC] < 0x10   { strings.write_string(sb, "0") }
  if regs.word[.PC] < 0x100  { strings.write_string(sb, "0") }
  if regs.word[.PC] < 0x1000 { strings.write_string(sb, "0") }
  strings.write_u64(sb, u64(regs.word[.PC]), 16)
  
  pc := regs.word[.PC]
  strings.write_string(sb, " PCMEM:")
  if memory_map[pc] < 0x10 { strings.write_string(sb, "0") }
  strings.write_u64(sb, u64(memory_map[pc]), 16)
  strings.write_string(sb, ",")
  pc += 1
  if memory_map[pc] < 0x10 { strings.write_string(sb, "0") }
  strings.write_u64(sb, u64(memory_map[pc]), 16)
  pc += 1
  strings.write_string(sb, ",")
  if memory_map[pc] < 0x10 { strings.write_string(sb, "0") }
  strings.write_u64(sb, u64(memory_map[pc]), 16)
  pc += 1
  strings.write_string(sb, ",")
  if memory_map[pc] < 0x10 { strings.write_string(sb, "0") }
  strings.write_u64(sb, u64(memory_map[pc]), 16)
  strings.write_string(sb, "\n")
  // fmt.sbprintf(sb, "A:%2x F:%2x B:%2x C:%2x D:%2x E:%2x H:%2x L:%2x SP:%4x PC:%4x PCMEM:%2x,%2x,%2x,%2x\n", regs.byte[.A], regs.byte[.F], regs.byte[.B], regs.byte[.C], regs.byte[.D], regs.byte[.E], regs.byte[.H], regs.byte[.L], regs.word[.SP], regs.word[.PC], memory_map[pc], memory_map[pc+1], memory_map[pc+2], memory_map[pc+3])
}