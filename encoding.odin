package main

Op_Param_Type :: enum u8 {
  none, r8 = 'r', r16 = 'w', r16stk = 'k', r16mem = 'm', cond = 'c', bi3 = 'i', tgt3 = 't', d8 = 'd', s8 = 's',
  
  a, sp, spl, sph, hl, stash, pc, imm8, c
}

Command_Type :: enum {
  illegal,
  
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
  clock, prefix,
}

Command :: struct {
  type: Command_Type,
  data: union { Register_Action, Memory_Action, Alu_Action }
}

Register_Action :: struct { reg: Op_Param_Type }
Memory_Action :: struct { address: Op_Param_Type }
Alu_Action :: struct { function: Alu_Function, rhs: Op_Param_Type }
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