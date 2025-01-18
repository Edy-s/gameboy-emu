#+private file
package main

import "core:fmt"

@(private)
opcode_table := [?]Op_Encoding{
  // Block 0
  {.nop, {}, {B("00000000")}},
  
  {.ld, {}, {B("00"), D(.r16),    B("0001"), S(.imm16)}},
  {.ld, {}, {B("00"), D(.r16mem), B("0010"), S(.a)}},
  {.ld, {}, {B("00"), S(.r16mem), B("1010"), D(.a)}},
  {.ld, {}, {B("00"), B("00"),    B("1000"), D(.imm16), S(.sp)}},
  
  {.inc, {}, {B("00"), D(.r16), B("0011")}},
  {.dec, {}, {B("00"), D(.r16), B("1011")}},
  {.add, {}, {B("00"), S(.r16), B("1001"), D(.hl)}},
  
  {.inc, {}, {B("00"), D(.r8), B("100")}},
  {.dec, {}, {B("00"), D(.r8), B("101")}},
  
  {.ld, {}, {B("00"), D(.r8), B("110"), S(.imm8)}},
  
  {.rot, {.rot_l}, {B("00"), B("000"), B("111"), D(.a)}},
  {.rot, {.rot_r}, {B("00"), B("001"), B("111"), D(.a)}},
  {.rot, {.rot_l, .rot_carry}, {B("00"), B("010"), B("111"), D(.a)}},
  {.rot, {.rot_r, .rot_carry}, {B("00"), B("011"), B("111"), D(.a)}},
  
  {.daa, {}, {B("00"), B("100"), B("111")}},
  {.cpl, {}, {B("00"), B("101"), B("111")}},
  {.scf, {}, {B("00"), B("110"), B("111")}},
  {.ccf, {}, {B("00"), B("111"), B("111")}},
  
  {.jmp, {.jmp_delta}, {B("00"), B("011"),         B("000"), S(.imm8)}},
  {.jmp, {.jmp_delta}, {B("00"), B("1"), O(.cond), B("000"), S(.imm8)}},
  
  {.stop, {}, {B("00010000")}}, // Must skip an instruction!
  
  // Block 1
  // The order of these following two instructions is important!
  {.halt, {}, {B("01"), B("110110")}},
  
  {.ld, {}, {B("01"), D(.r8), S(.r8)}},
  
  // Block 2
  {.add, {},           {B("10"), B("000"), S(.r8), D(.a)}},
  {.add, {.use_carry}, {B("10"), B("001"), S(.r8), D(.a)}},
  {.sub, {},           {B("10"), B("010"), S(.r8), D(.a)}},
  {.sub, {.use_carry}, {B("10"), B("011"), S(.r8), D(.a)}},
  {.and, {},           {B("10"), B("100"), S(.r8), D(.a)}},
  {.xor, {},           {B("10"), B("101"), S(.r8), D(.a)}},
  {.or,  {},           {B("10"), B("110"), S(.r8), D(.a)}},
  {.cp,  {},           {B("10"), B("111"), S(.r8), D(.a)}},
  
  // Block 3
  {.illegal, {}, {B("11010011")}},
  {.illegal, {}, {B("11011011")}},
  {.illegal, {}, {B("11011101")}},
  {.illegal, {}, {B("11100011")}},
  {.illegal, {}, {B("11100100")}},
  {.illegal, {}, {B("11101011")}},
  {.illegal, {}, {B("11101100")}},
  {.illegal, {}, {B("11101101")}},
  {.illegal, {}, {B("11110100")}},
  {.illegal, {}, {B("11111100")}},
  {.illegal, {}, {B("11111101")}},
  
  {.add, {},           {B("11"), B("000"), B("110"), D(.a), S(.imm8)}},
  {.add, {.use_carry}, {B("11"), B("001"), B("110"), D(.a), S(.imm8)}},
  {.sub, {},           {B("11"), B("010"), B("110"), D(.a), S(.imm8)}},
  {.sub, {.use_carry}, {B("11"), B("011"), B("110"), D(.a), S(.imm8)}},
  {.and, {},           {B("11"), B("100"), B("110"), D(.a), S(.imm8)}},
  {.xor, {},           {B("11"), B("101"), B("110"), D(.a), S(.imm8)}},
  {.or,  {},           {B("11"), B("110"), B("110"), D(.a), S(.imm8)}},
  {.cp,  {},           {B("11"), B("111"), B("110"), D(.a), S(.imm8)}},
  
  {.ret,  {}, {B("11"), B("0"), O(.cond), B("000")}},
  {.ret,  {}, {B("11"), B("001"), B("001")}},
  {.reti, {}, {B("11"), B("011"), B("001")}},
  
  {.jmp, {}, {B("11"), B("0"), O(.cond), B("010"), S(.imm16)}},
  {.jmp, {}, {B("11"), B("000"),         B("011"), S(.imm16)}},
  {.jmp, {}, {B("11"), B("101"),         B("001"), S(.hl)}},
  
  {.call, {}, {B("11"), B("0"), O(.cond), B("100"), S(.imm16)}},
  {.call, {}, {B("11"), B("001"),         B("101"), S(.imm16)}},
  
  {.rst, {}, {B("11"), S(.tgt3), B("111")}},
  
  {.pop,  {}, {B("11"), S(.r16stk), B("0001")}},
  {.push, {}, {B("11"), S(.r16stk), B("0101")}},
  
  {.prefix, {}, {B("11"), B("001011")}},
  
  {.ld, {}, {B("11"), B("100010"), D(.c_addr), S(.a)}},
  {.ld, {}, {B("11"), B("100000"), D(.imm8_addr), S(.a)}},
  {.ld, {}, {B("11"), B("101010"), D(.imm16_addr), S(.a)}},
  {.ld, {}, {B("11"), B("110010"), D(.a), S(.c_addr)}},
  {.ld, {}, {B("11"), B("110000"), D(.a), S(.imm8_addr)}},
  {.ld, {}, {B("11"), B("111010"), D(.a), S(.imm16_addr)}},
  
  {.add, {}, {B("11"), B("101000"), D(.sp), S(.imm8)}},
  {.ld, {},  {B("11"), B("111000"), D(.hl), S(.e8)}},
  {.ld, {},  {B("11"), B("111001"), D(.sp), S(.hl)}},
  
  {.di, {}, {B("11"), B("110011")}},
  {.ei, {}, {B("11"), B("111011")}},
}

@(private)
opcode_table_prefixed := [?]Op_Encoding{
  {.rot, {.rot_l}, {B("00"), B("000"), D(.r8)}},
  {.rot, {.rot_r}, {B("00"), B("001"), D(.r8)}},
  {.rot, {.rot_l, .rot_carry}, {B("00"), B("010"), D(.r8)}},
  {.rot, {.rot_r, .rot_carry}, {B("00"), B("011"), D(.r8)}},
  {.sla, {},  {B("00"), B("100"), D(.r8)}},
  {.sra, {},  {B("00"), B("101"), D(.r8)}},
  {.srl, {},  {B("00"), B("111"), D(.r8)}},
  {.swap, {}, {B("00"), B("110"), D(.r8)}},
  
  {.bit, {}, {B("01"), O(.bi3), D(.r8)}},
  {.res, {}, {B("10"), O(.bi3), D(.r8)}},
  {.set, {}, {B("11"), O(.bi3), D(.r8)}},
}

B :: proc(bit_pattern: string) -> (result: Bit_Pattern) {
  result.bit_count = u16(len(bit_pattern))
  for char in bit_pattern {
    result.value = result.value << 1
    switch char {
    case '1':
      result.value |= 1
    case '0':
    case:
      panic(fmt.aprintf("Bit pattern should only have 1's and 0's, but this one had a %v. Full string: %v\n", char, bit_pattern))
    }
  }
  return
}

D :: proc(op_type: Op_Param_Type) -> (result: Op_Param) {
  result.type = op_type
  result.term = .dest
  return
}

S :: proc(op_type: Op_Param_Type) -> (result: Op_Param) {
  result.type = op_type
  result.term = .source
  return
}

O :: proc(op_type: Op_Param_Type) -> (result: Op_Param) {
  result.type = op_type
  return
}