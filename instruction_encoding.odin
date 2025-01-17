package main

Op_Encoding :: struct {
  op: Operators,
  params: struct {
    // dest, dest_a, src, src_a: CPU_Locations,
    rot: enum {l, r},
    rot_carry: bool,
    use_carry: bool,
    jmp_delta: bool,
    cond: bool,
  },
  encodings: []union { Bit_Pattern, Op_Param },
}

Bit_Pattern :: struct {
  value: u8,
  bit_count: u16,
}

Op_Param :: struct {
  term: Op_Param_Term,
  type: Op_Param_Type,
}

Op_Param_Type :: enum { 
  r8, r16, r16stk, r16mem, cond, bi3, tgt3, // Actual parameters
  imm8, imm16, imm8_addr, imm16_addr, e8, // Extra bytes
  a, sp, hl, c_addr, // "Built-In" operands
}

Op_Param_Type_Sizes := #partial [Op_Param_Type]u8 {
  .r8 = 3,
  .r16 = 2, .r16stk = 2, .r16mem = 2, .cond = 2, .bi3 = 3, .tgt3 = 3,
  // .imm8 = 8, .imm16 = 16
}

Op_Param_Term :: enum { none, dest, source }

Operators :: enum {
  nop = 1,
  
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
  
  illegal,
}

Term :: struct {
  type: Op_Param_Type,
  value8:  u8,
  value16: u16,
}

Instruction :: struct {
  op: Operators,
  
  terms : [Op_Param_Term]Term,
  
  set_params: bit_set[Op_Param_Type],
  params: [Op_Param_Type]u8,
}