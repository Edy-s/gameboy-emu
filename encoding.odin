package main

Op_Param_Type :: enum u16 {
  none, r8 = 'r', r16 = 'w', r16stk = 'k', r16mem = 'm', cond = 'c', bi3 = 'i', tgt3 = 't', d8 = 'd', s8 = 's',
  
  a = 255, sp, spl, sph, hl, pc, c
}

Command_Type :: enum {
  illegal, nop,
  
  next,
  load, store,
  write, read,
  push, pop,
  alu,
  check_condition,
  stash, unstash, inc_stash,
  halt, stop,
  set_i, clear_i,
  rst,
  
  set_msb,
  clock, prefix, handle_interrupt,
}

Command :: struct {
  type: Command_Type,
  data: union { Register_Action, Alu_Action }
}

Opcode :: struct {
  opcode_string: string,
  reference_byte: u8 `fmt:"x"`,
  params: [2]struct {
    type: Op_Param_Type,
    value: u8,
  },
  timing: struct { min, max: int }
}

Register_Action :: struct { reg: Op_Param_Type }
Alu_Action      :: struct { function: Alu_Function, has_rhs: bool, set_flags: bool }

Alu_Function :: enum {
  INC, DEC, ADD, ADC, SUB, SBC,
  AND, XOR, OR, CP,
  RLC, RRC, RL, RR,
  DAA, CPL, SCF, CCF,
  SIGNED_ADD,
  SLA, SRA,
  SRL,
  SWAP,
  BIT, RES, SET,
}