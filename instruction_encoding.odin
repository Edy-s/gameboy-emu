package main

Op_Encoding :: struct {
  op: Operators,
  params: struct {
    dest, dest_a, src, src_a: CPU_Locations,
    rot: enum {l, r},
    rot_carry: bool,
    use_carry: bool,
    jmp_delta: bool,
    cond: bool,
  },
  encoding: []Bit_Field
}

Operators :: enum {
  nop,
  
  ld, swap,
  
  add, sub, dec, inc, 
  
  xor, or, cpl, and,
  
  rot, sla, sra, srl, bit, res, set,
  
  daa, scf, ccf,
  
  cp,
  
  jmp, ret, reti, call, rst, push, pop,
  
  stop, halt,
  di, ei,
  
  prefix,
}

CPU_Locations :: enum {
  a, b, c, d, e, h, l,
  
  hl, sp, e8,
  
  r8, r16, imm8, imm16, r16mem, r16stk,
  
  tgt3,
}

Bit_Field :: struct {
  type: enum { bit_pattern, r8, r16, r16stk, r16mem, imm8, imm16, tgt3, cc, bit_index },
  value: u16,
  bit_count: int,
}