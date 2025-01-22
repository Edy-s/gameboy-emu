#+private file
package main

import "core:fmt"

Op_Encoding_V2 :: struct {
  opcode_string: string,
  opcode: Opcode,
  commands: []Command,
}

Op_Param :: struct {
  type: Op_Param_Type,
  mask, r_offset: u8,
}

Opcode :: struct {
  mask: u8,
  value: u8,
  
  params: [2]Op_Param,
}

B :: proc(bit_pattern: string) -> (result: Opcode) {
  assert(len(bit_pattern) == 8)
  
  params_found := -1
  nil_param: Op_Param
  edit_param: ^Op_Param = &nil_param
  
  for char, i in bit_pattern {
    result.mask  <<= 1
    result.value <<= 1
    result.params[0].mask <<= 1
    result.params[1].mask <<= 1
    switch char {
    case '1':
      result.value |= 1
      result.mask  |= 1
      
      edit_param.r_offset = 8 - u8(i)
      edit_param = &nil_param
      
    case '0':
      result.mask  |= 1
      
      edit_param.r_offset = 8 - u8(i)
      edit_param = &nil_param
      
    case 'r', 'w', 'k', 'm', 'c', 'i', 't', 'd', 's':
      edit_param.r_offset = 8 - u8(i)
      
      params_found += 1
      edit_param = &result.params[params_found]
      edit_param.type = Op_Param_Type(char)
      edit_param.mask     |= 1
      
    case '_':
      edit_param.mask |= 1
      
    case:
      panic(fmt.aprintf("Undesired character in a bit pattern - %v. Full string: %v\n", char, bit_pattern))
    }
  }
  return
}

next      :: Command{type = .next}
stash     :: Command{type = .stash}
unstash   :: Command{type = .unstash}
inc_stash :: Command{type = .inc_stash}
check_condition :: Command{type = .check_condition}
stop    :: Command{type = .stop}
halt    :: Command{type = .halt}
illegal :: Command{type = .illegal}
clock   :: Command{type = .clock}
push    :: Command{type = .push}
pop     :: Command{type = .pop}
set_i   :: Command{type = .set_i}
clear_i :: Command{type = .clear_i}
rst     :: Command{type = .rst}
prefix  :: Command{type = .prefix}
set_msb :: Command{type = .set_msb}
// illegal :: Command{type = .illegal}

store_reg :: proc(param: Op_Param_Type) -> (cmd: Command) {
  cmd.type = .store
  cmd.data = Register_Action{param}
  return
}
load_reg :: proc(param: Op_Param_Type) -> (cmd: Command) {
  cmd.type = .load
  cmd.data = Register_Action{param}
  return
}
write_mem :: proc(address: Op_Param_Type) -> (cmd: Command) {
  cmd.type = .write
  cmd.data = Memory_Action{address}
  return
}
read_mem :: proc(address: Op_Param_Type) -> (cmd: Command) {
  cmd.type = .read
  cmd.data = Memory_Action{address}
  return
}
alu :: proc(function: Alu_Function, set_flags := true) -> (cmd: Command) {
  cmd.type = .alu
  cmd.data = Alu_Action{function, false, set_flags}
  return
}

alu2 :: proc(function: Alu_Function, set_flags := true) -> (cmd: Command) {
  cmd.type = .alu
  cmd.data = Alu_Action{function, true, set_flags}
  return
}

@(private)
opcode_table_v2 := [?]Op_Encoding_V2{
  // Block 0
  {"nop", B("00000000"), {}}, // 1cc
  
  {"ld %v, word %v",   B("00w_0001"), {next, next, store_reg(.r16)}}, // 3cc
  {"ld [%v], a",       B("00m_0010"), {load_reg(.a), write_mem(.r16mem)}}, // 2cc
  {"ld a, [%v]",       B("00m_1010"), {read_mem(.r16mem), store_reg(.a)}}, // 2cc
  {"ld [word %v], sp", B("00001000"), {next, next, stash, load_reg(.spl), write_mem(.stash), inc_stash, load_reg(.sph), write_mem(.stash)}}, // 5cc
  
  {"inc %v",     B("00w_0011"), {load_reg(.r16), alu(.INC), store_reg(.r16)}}, // 2cc
  {"dec %v",     B("00w_1011"), {load_reg(.r16), alu(.DEC), store_reg(.r16)}}, // 2cc
  {"add hl, %v", B("00w_0011"), {load_reg(.r16), stash, load_reg(.hl), alu2(.ADD), store_reg(.hl)}}, // 2cc
  
  {"inc %v", B("00r__100"), {load_reg(.r8), alu(.INC), store_reg(.r8)}}, // 1cc
  {"dec %v", B("00r__101"), {load_reg(.r8), alu(.DEC), store_reg(.r8)}}, // 1cc
  
  {"ld %v", B("00r__110"), {next, store_reg(.r8)}}, // 2cc
  
  {"rlca", B("00000111"), {load_reg(.a), alu(.RLC), store_reg(.a)}}, // 1cc
  {"rrca", B("00001111"), {load_reg(.a), alu(.RRC), store_reg(.a)}}, // 1cc
  {"rla",  B("00010111"), {load_reg(.a), alu(.RL),  store_reg(.a)}}, // 1cc
  {"rra",  B("00011111"), {load_reg(.a), alu(.RR),  store_reg(.a)}}, // 1cc
  
  {"daa", B("00100111"), {alu(.DAA)}}, // 1cc
  {"cpl", B("00101111"), {alu(.CPL)}}, // 1cc
  {"scf", B("00110111"), {alu(.SCF)}}, // 1cc
  {"ccf", B("00111111"), {alu(.CCF)}}, // 1cc
  
  {"jr %i",      B("00011000"), {next, stash,                  load_reg(.pc), alu2(.SIGNED_ADD, set_flags = false), store_reg(.pc)}}, // 3cc 
  {"jr %v, $%i", B("001c_000"), {next, stash, check_condition, load_reg(.pc), alu2(.SIGNED_ADD, set_flags = false), store_reg(.pc)}}, // 2-3cc
  
  {"stop", B("00010000"), {stop}},
  
  // Block 1
  // The order of these following two instructions is important!
  {"halt", B("01110110"), {halt}}, // ?cc
  
  {"ld %v, %v", B("01d__s__"), {load_reg(.s8), store_reg(.d8)}}, // 1cc
  
  // Block 2
  {"add a, %v", B("10000r__"), {load_reg(.r8), stash, load_reg(.a), alu2(.ADD), store_reg(.a)}}, // 1-2cc
  {"adc a, %v", B("10001r__"), {load_reg(.r8), stash, load_reg(.a), alu2(.ADC), store_reg(.a)}}, // 1-2cc
  {"sub a, %v", B("10010r__"), {load_reg(.r8), stash, load_reg(.a), alu2(.SUB), store_reg(.a)}}, // 1-2cc
  {"sbc a, %v", B("10011r__"), {load_reg(.r8), stash, load_reg(.a), alu2(.SBC), store_reg(.a)}}, // 1-2cc
  {"and a, %v", B("10100r__"), {load_reg(.r8), stash, load_reg(.a), alu2(.AND), store_reg(.a)}}, // 1-2cc
  {"xor a, %v", B("10101r__"), {load_reg(.r8), stash, load_reg(.a), alu2(.XOR), store_reg(.a)}}, // 1-2cc
  {"or  a, %v", B("10110r__"), {load_reg(.r8), stash, load_reg(.a), alu2(.OR),  store_reg(.a)}}, // 1-2cc
  {"cp  a, %v", B("10111r__"), {load_reg(.r8), stash, load_reg(.a), alu2(.CP),  store_reg(.a)}}, // 1-2cc
  
  // Block 3
  {"xxx", B("11010011"), {illegal}}, // 1cc
  {"xxx", B("11011011"), {illegal}}, // 1cc
  {"xxx", B("11011101"), {illegal}}, // 1cc
  {"xxx", B("11100011"), {illegal}}, // 1cc
  {"xxx", B("11100100"), {illegal}}, // 1cc
  {"xxx", B("11101011"), {illegal}}, // 1cc
  {"xxx", B("11101100"), {illegal}}, // 1cc
  {"xxx", B("11101101"), {illegal}}, // 1cc
  {"xxx", B("11110100"), {illegal}}, // 1cc
  {"xxx", B("11111100"), {illegal}}, // 1cc
  {"xxx", B("11111101"), {illegal}}, // 1cc
  
  {"add a, byte %i", B("11000110"), {next, stash, load_reg(.a), alu2(.ADD), store_reg(.a)}}, // 2cc
  {"adc a, byte %i", B("11001110"), {next, stash, load_reg(.a), alu2(.ADC), store_reg(.a)}}, // 2cc
  {"sub a, byte %i", B("11010110"), {next, stash, load_reg(.a), alu2(.SUB), store_reg(.a)}}, // 2cc
  {"sbc a, byte %i", B("11011110"), {next, stash, load_reg(.a), alu2(.SBC), store_reg(.a)}}, // 2cc
  {"and a, byte %i", B("11100110"), {next, stash, load_reg(.a), alu2(.AND), store_reg(.a)}}, // 2cc
  {"xor a, byte %i", B("11101110"), {next, stash, load_reg(.a), alu2(.XOR), store_reg(.a)}}, // 2cc
  {"or  a, byte %i", B("11110110"), {next, stash, load_reg(.a), alu2(.OR),  store_reg(.a)}}, // 2cc
  {"cp  a, byte %i", B("11111110"), {next, stash, load_reg(.a), alu2(.CP),  store_reg(.a)}}, // 2cc
  
  {"ret %v", B("110c_000"), {clock, check_condition, pop, pop, store_reg(.pc)}}, // 2-5cc
  {"ret",    B("11001001"), {pop, pop, store_reg(.pc)}}, // 4cc
  {"reti",   B("11011001"), {pop, pop, store_reg(.pc), set_i}}, // 4cc
  
  {"jp %v, word %v", B("110c_010"), {next, next, check_condition, store_reg(.pc)}}, // 3-4cc
  {"jp word %v",     B("11000011"), {next, next, store_reg(.pc), clock}}, // 4cc
  {"jp hl",          B("11101001"), {load_reg(.hl), store_reg(.pc)}}, // 1cc
  
  {"call %v, word $%v", B("110c_100"), {next, next, stash, check_condition, load_reg(.pc), push, push, unstash, store_reg(.pc)}}, // 3-6cc
  {"call word $%v",     B("11001101"), {next, next, stash,                  load_reg(.pc), push, push, unstash, store_reg(.pc)}}, // 6cc
  
  {"rst %2x", B("11t__111"), {rst}}, // 4cc
  
  {"pop  %v", B("11k_0001"), {pop, pop, store_reg(.r16stk)}}, // 3cc
  {"push %v", B("11k_0101"), {load_reg(.r16stk), clock, push, push}}, // 4cc
  
  {"", B("11001011"), {prefix}}, // 1cc
  
  {"ldh [c],  a",      B("11100010"), {load_reg(.c), set_msb, stash, load_reg(.a), write_mem(.stash)}}, // 2cc
  {"ldh [byte %v], a", B("11100000"), {next,         set_msb, stash, load_reg(.a), write_mem(.stash)}}, // 3cc
  {"ld [word %v], a",  B("11101010"), {next,         next,    stash, load_reg(.a), write_mem(.stash)}}, // 4cc
  {"ldh a, [c]",       B("11110010"), {load_reg(.c), set_msb, stash, read_mem(.stash), store_reg(.a)}}, // 2cc
  {"ldh a, [byte %v]", B("11110000"), {next,         set_msb, stash, read_mem(.stash), store_reg(.a)}}, // 3cc
  {"ld a, [word %v]",  B("11111010"), {next,         next,    stash, read_mem(.stash), store_reg(.a)}}, // 4cc
  
  
  {"add sp, byte %v",      B("11101000"), {next, stash, load_reg(.sp), alu2(.SIGNED_ADD), clock, store_reg(.sp)}}, // 4cc
  {"ld hl, sp + byte %v",  B("11111000"), {next, stash, load_reg(.sp), alu2(.SIGNED_ADD), store_reg(.hl)}}, // 3cc
  {"ld sp, hl",            B("11111001"), {load_reg(.hl), store_reg(.sp), clock}}, // 2cc

  {"di", B("11110011"), {clear_i}}, // 1cc
  {"di", B("11111011"), {set_i}}, // 1cc
}

@(private)
opcode_table_prefixed_v2 := [?]Op_Encoding_V2{
  {"rlc %v",  B("00000r__"), {load_reg(.r8), alu(.RLC),  store_reg(.r8)}}, // 1-3cc
  {"rrc %v",  B("00001r__"), {load_reg(.r8), alu(.RRC),  store_reg(.r8)}}, // 1-3cc
  {"rl %v",   B("00010r__"), {load_reg(.r8), alu(.RL),   store_reg(.r8)}}, // 1-3cc
  {"rr %v",   B("00011r__"), {load_reg(.r8), alu(.RR),   store_reg(.r8)}}, // 1-3cc
  {"sla %v",  B("00100r__"), {load_reg(.r8), alu(.SLA),  store_reg(.r8)}}, // 1-3cc
  {"sra %v",  B("00101r__"), {load_reg(.r8), alu(.SRA),  store_reg(.r8)}}, // 1-3cc
  {"srl %v",  B("00111r__"), {load_reg(.r8), alu(.SRL),  store_reg(.r8)}}, // 1-3cc
  {"swap %v", B("00110r__"), {load_reg(.r8), alu(.SWAP), store_reg(.r8)}}, // 1-3cc
  
  {"bit %v, %v,", B("01i__r__"), {load_reg(.r8), alu(.BIT), store_reg(.r8)}}, // 1-3cc
  {"res %v, %v,", B("10i__r__"), {load_reg(.r8), alu(.RES), store_reg(.r8)}}, // 1-3cc
  {"set %v, %v,", B("11i__r__"), {load_reg(.r8), alu(.SET), store_reg(.r8)}}, // 1-3cc
}