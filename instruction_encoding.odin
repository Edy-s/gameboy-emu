package main

Op_Encoding :: struct {
  op: Operators,
  modifiers: bit_set[Op_Modifiers],
  encodings: []union { Bit_Pattern, Op_Param },
}

Op_Modifiers :: enum {
  rot_l, rot_r, rot_carry,
  use_carry,
  jmp_delta,
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
  NOT_SET,
  
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
  NOT_SET,
  
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
  
  illegal,
}

Term :: struct {
  type: Op_Param_Type,
  value8:  u8,
  value16: u16,
}

Instruction :: struct {
  op: Operators,
  
  dest_term, source_term: Term,
  
  set_params: bit_set[Op_Param_Type],
  params: [Op_Param_Type]u8,
  modifiers: bit_set[Op_Modifiers],
}

import "core:reflect"
pretty_print_instruction :: proc(instr: Instruction) {
  zeroed_instr :: Instruction{}
  using reflect
  fields := struct_fields_zipped(type_of(instr))
  for field in fields {
    val := struct_field_value(instr, field)
    nil_val := struct_field_value(zeroed_instr, field)
    if !equal(val, nil_val, true) {
      print("%v = %v\n", field.name, val)
    }
  }
  print("\n")
}