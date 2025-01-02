#+private file
package main

import "core:fmt"

B :: proc(bit_pattern: string) -> (result: Bit_Field) {
  result.type = .bit_pattern
  result.bit_count = len(bit_pattern)
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

R8 ::     Bit_Field{.r8, 0, 3}
R16 ::    Bit_Field{.r16, 0, 2}
R16STK :: Bit_Field{.r16stk, 0, 2}
R16MEM :: Bit_Field{.r16mem, 0, 2}

IMM8 ::  Bit_Field{.imm8, 0, 8}
IMM16 :: Bit_Field{.imm16, 0, 16}

BIT_INDEX :: Bit_Field{.bit_index, 0, 3}
TGT3 :: Bit_Field{.tgt3, 0, 3}
CC :: Bit_Field{.cc, 0, 2}


@(private)
opcode_table := [?]Op_Encoding{
  {.nop, {}, {B("00000000")}},
  
  {.ld, {dest = .r16, src = .imm16},  {B("00"), R16, B("0001"), IMM16}},
  {.ld, {dest_a = .r16mem, src = .a}, {B("00"), R16, B("0010")}},
  {.ld, {dest = .a, src_a = .r16mem}, {B("00"), R16, B("1010")}},
  {.ld, {dest_a = .imm16, src = .sp}, {B("00"), B("00"), B("1000"), IMM16}},
  
  {.inc, {dest = .r16}, {B("00"), R16, B("0011")}},
  {.dec, {dest = .r16}, {B("00"), R16, B("1011")}},
  {.add, {dest = .hl, src = .r16}, {B("00"), R16, B("1001")}},
  
  {.ld, {dest = .r8, src = .imm8}, {B("00"), R8,  B("110"), IMM8}},
  
  {.rot, {dest = .a, rot = .l}, {B("00"), B("000"), B("111")}},
  {.rot, {dest = .a, rot = .r}, {B("00"), B("001"), B("111")}},
  {.rot, {dest = .a, rot = .l, rot_carry = true}, {B("00"), B("010"), B("111")}},
  {.rot, {dest = .a, rot = .r, rot_carry = true}, {B("00"), B("011"), B("111")}},
  
  {.daa, {}, {B("00"), B("100"), B("111")}},
  {.cpl, {}, {B("00"), B("101"), B("111")}},
  {.scf, {}, {B("00"), B("110"), B("111")}},
  {.ccf, {}, {B("00"), B("111"), B("111")}},
  
  {.jmp, {jmp_delta = true},              {B("00"), B("011"),   B("000"), IMM8}},
  {.jmp, {jmp_delta = true, cond = true}, {B("00"), B("1"), CC, B("000"), IMM8}},
  
  {.stop, {}, {B("00010000"), IMM8}}, // Potentially shouldn't take the 2nd byte, instead skip 1 instruction on execution
  
  
  {.ld, {dest = .r8, src = .r8}, {B("01"), R8, R8}},
  
  {.halt, {}, {B("01"), B("110110")}},
  
  {.add, {dest = .a, src = .r8},                   {B("10"), B("000"), R8}},
  {.add, {dest = .a, src = .r8, use_carry = true}, {B("10"), B("001"), R8}},
  {.sub, {dest = .a, src = .r8},                   {B("10"), B("010"), R8}},
  {.sub, {dest = .a, src = .r8, use_carry = true}, {B("10"), B("011"), R8}},
  {.and, {dest = .a, src = .r8},                   {B("10"), B("100"), R8}},
  {.xor, {dest = .a, src = .r8},                   {B("10"), B("100"), R8}},
  {.or,  {dest = .a, src = .r8},                   {B("10"), B("100"), R8}},
  {.cp,  {dest = .a, src = .r8},                   {B("10"), B("100"), R8}},
  
  
  {.add, {dest = .a, src = .imm8},                   {B("11"), B("000"), B("110"), IMM8}},
  {.add, {dest = .a, src = .imm8, use_carry = true}, {B("11"), B("001"), B("110"), IMM8}},
  {.sub, {dest = .a, src = .imm8},                   {B("11"), B("010"), B("110"), IMM8}},
  {.sub, {dest = .a, src = .imm8, use_carry = true}, {B("11"), B("011"), B("110"), IMM8}},
  {.and, {dest = .a, src = .imm8},                   {B("11"), B("100"), B("110"), IMM8}},
  {.xor, {dest = .a, src = .imm8},                   {B("11"), B("100"), B("110"), IMM8}},
  {.or,  {dest = .a, src = .imm8},                   {B("11"), B("100"), B("110"), IMM8}},
  {.cp,  {dest = .a, src = .imm8},                   {B("11"), B("100"), B("110"), IMM8}},
  
  {.ret, {cond = true}, {B("11"), B("0"), CC, B("000")}},
  {.ret,  {}, {B("11"), B("001"), B("001")}},
  {.reti, {}, {B("11"), B("011"), B("001")}},
  
  {.jmp, {cond = true, src = .imm8}, {B("11"), B("0"), CC, B("010"), IMM8}},
  {.jmp, {src = .imm8}, {B("11"), B("000"), B("011"), IMM8}},
  {.jmp, {src = .hl},   {B("11"), B("101"), B("001")}},
  
  {.call, {cond = true, src = .imm16}, {B("11"), B("0"), CC, B("100"), IMM16}},
  {.call, {src = .imm16},              {B("11"), B("001"), B("101"), IMM16}},
  
  {.rst, {src = .tgt3}, {B("11"), TGT3, B("111")}},
  
  {.pop,  {dest = .r16stk}, {B("11"), R16STK, B("0001")}},
  {.push, {dest = .r16stk}, {B("11"), R16STK, B("0101")}},
  
  {.prefix, {}, {B("11"), B("001011")}},
  
  {.ld, {dest_a = .c, src = .a},     {B("11"), B("100010")}},
  {.ld, {dest_a = .imm8, src = .a},  {B("11"), B("100000"), IMM8}},
  {.ld, {dest_a = .imm16, src = .a}, {B("11"), B("101010"), IMM16}},
  {.ld, {dest = .a, src_a = .c},     {B("11"), B("110010")}},
  {.ld, {dest = .a, src_a = .imm8},  {B("11"), B("110000"), IMM8}},
  {.ld, {dest = .a, src_a = .imm16}, {B("11"), B("111010"), IMM16}},
  
  {.add, {dest = .sp, src = .imm8}, {B("11"), B("101000"), IMM8}},
  {.ld, {dest = .hl, src = .e8}, {B("11"), B("111000"), IMM8}},
  {.ld, {dest = .sp, src = .hl}, {B("11"), B("111001")}},
  
  {.di, {}, {B("11"), B("110011")}},
  {.ei, {}, {B("11"), B("111011")}},
}

@(private)
opcode_table_prefixed := [?]Op_Encoding{
  {.rot, {dest = .r8, rot = .l}, {B("00"), B("000"), R8}},
  {.rot, {dest = .r8, rot = .r}, {B("00"), B("001"), R8}},
  {.rot, {dest = .r8, rot = .l, rot_carry = true}, {B("00"), B("010"), R8}},
  {.rot, {dest = .r8, rot = .r, rot_carry = true}, {B("00"), B("011"), R8}},
  {.sla, {dest = .r8}, {B("00"), B("100"), R8}},
  {.sra, {dest = .r8}, {B("00"), B("101"), R8}},
  {.srl, {dest = .r8}, {B("00"), B("111"), R8}},
  {.swap, {dest = .r8}, {B("00"), B("110"), R8}},
  
  {.bit, {dest = .r8}, {B("01"), BIT_INDEX, R8}},
  {.res, {dest = .r8}, {B("10"), BIT_INDEX, R8}},
  {.set, {dest = .r8}, {B("11"), BIT_INDEX, R8}},
}