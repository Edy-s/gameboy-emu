package main

import "core:strings"
import "core:os"

gb_doc_log: strings.Builder
log_line: int

do_logging: bool

init_log :: proc() {
  gb_doc_log = strings.builder_make()
}

log_instr :: proc() {
  instr_state.printed = true
  if !do_logging { return }
  bingus :: union{Reg_Byte, Reg_Word, string, u8, u16}
  printout: [2]bingus
  to_print: u8
  for i in 0..<2 {
    tp  := instr_state.op.params[i].type
    val := instr_state.op.params[i].value
    #partial switch tp {
    case .r8, .d8, .s8:
      r8, mem_hl := r8_mapping(val)
      if mem_hl {
        printout[to_print] = "[HL]"
      } else {
        printout[to_print] = r8
      }
    case .cond:
      switch val {
      case 0: printout[to_print] = "NZ"
      case 1: printout[to_print] = "Z"
      case 2: printout[to_print] = "NC"
      case 3: printout[to_print] = "C"
    }
    case .r16:
      r16 := r16_mapping[val]
      printout[to_print] = r16
    case .r16stk:
      r16stk := r16stk_mapping[val]
      printout[to_print] = r16stk
    case .r16mem:
      r16mem, _ := r16mem_mapping(val)
      if      val == 2 { printout[to_print] = "HL+" }
      else if val == 3 { printout[to_print] = "HL-" }
      else { printout[to_print] = r16mem }
    }
    if printout[to_print] != nil { to_print += 1 }
  }
  
  if instr_state.info.bytes_set == 1 {
    printout[to_print] = instr_state.info.data.bytes.lsb
    to_print += 1
  }
  if instr_state.info.bytes_set == 2 {
    printout[to_print] = instr_state.info.data.word
    to_print += 1
  }
  
  assert(to_print <= 2)
  print("%4x ", instr_state.op_location)
  if to_print == 0 { print(instr_state.op.opcode_string) }
  if to_print == 1 { print(instr_state.op.opcode_string, printout[0]) }
  if to_print == 2 { print(instr_state.op.opcode_string, printout[0], printout[1]) }
  print("\n")
}


log_for_doc :: proc() {
  if len(os.args) != 3 { return }
  log_line += 1
  sb := &gb_doc_log
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
  if read_at(pc) < 0x10 { strings.write_string(sb, "0") }
  strings.write_u64(sb, u64(read_at(pc)), 16)
  strings.write_string(sb, ",")
  pc += 1
  if read_at(pc) < 0x10 { strings.write_string(sb, "0") }
  strings.write_u64(sb, u64(read_at(pc)), 16)
  pc += 1
  strings.write_string(sb, ",")
  if read_at(pc) < 0x10 { strings.write_string(sb, "0") }
  strings.write_u64(sb, u64(read_at(pc)), 16)
  pc += 1
  strings.write_string(sb, ",")
  if read_at(pc) < 0x10 { strings.write_string(sb, "0") }
  strings.write_u64(sb, u64(read_at(pc)), 16)
  strings.write_string(sb, "\n")
  // fmt.sbprintf(sb, "A:%2x F:%2x B:%2x C:%2x D:%2x E:%2x H:%2x L:%2x SP:%4x PC:%4x PCMEM:%2x,%2x,%2x,%2x\n", regs.byte[.A], regs.byte[.F], regs.byte[.B], regs.byte[.C], regs.byte[.D], regs.byte[.E], regs.byte[.H], regs.byte[.L], regs.word[.SP], regs.word[.PC], read_at(pc), memory_map[pc+1], memory_map[pc+2], memory_map[pc+3])
}
