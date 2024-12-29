package main

import "core:os"
import "core:fmt"

main :: proc() {
  file, ok := os.read_entire_file_from_filename("D:/codes/gameboy_emulator/gb-test-roms/cpu_instrs/individual/09-op r,r.gb")
  if !ok {
    fmt.printf("Couldn't read file\n")
    return
  }
  
  for byte in file {
    if byte == 0 { continue }
    fmt.printf("%x\n", byte)
  }
}


opcode_table := [?]Op_Encoding{
  {.nop, {}, {B("00000000")}},
  
  {.ld, {dest = .r16, src = .imm16}, {B("00"), R16, B("0001"), IMM16}},
  {.ld, {dest = .r16mem, src = .a},  {B("00"), R16, B("0010")}},
  {.ld, {dest = .a, src = .r16mem},  {B("00"), R16, B("1010")}},
  {.ld, {dest = .imm16, src = .sp},  {B("00"), B("00"), B("1000"), IMM16}},
  
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
  
  {.jmp, {jmp = .relative},                  {B("00"), B("011"),   B("000"), IMM8}},
  {.jmp, {jmp = .relative, conditional = true}, {B("00"), B("1"), CC, B("000"), IMM8}},
  
  {.stop, {}, {B("00010000"), IMM8}}, // Potentially shouldn't take the 2nd byte, instead skip 1 instruction on execution
  
  
  {.ld, {dest = .r8, src = .r8}, {B("01"), R8, R8}},
  
  {.halt, {}, {B("01110110")}},
  
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
  
  {.ret,  {conditional = true}, {B("11"), B("0"), CC, B("000")}},
  
}
  
  