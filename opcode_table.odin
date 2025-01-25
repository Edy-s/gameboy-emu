#+private file
package main

import "core:fmt"

Op_Encoding_V2 :: struct {
  opcode_string: string,
  opcode: Opcode,
  commands: []Command,
  timing: struct { min, max: int }
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

@(private)
INTERRUPT_COMMANDS := [?]Command{ load_reg(.pc), alu(.DEC), clock, push, push, {.handle_interrupt, {}} }

@(private)
opcode_table_v2 := [?]Op_Encoding_V2{
  // Block 0
  {"nop", B("00000000"), {{.nop, {}}}, {1, 1}}, // 1clocks
  
  {"ld %v, word %4x",   B("00w_0001"), {next, next, store_reg(.r16)}, {3, 3}}, // 3clocks
  {"ld [%v], a",        B("00m_0010"), {load_reg(.r16mem), stash, load_reg(.a), write_mem}, {2, 2}}, // 2clocks
  {"ld a, [%v]",        B("00m_1010"), {load_reg(.r16mem), stash, read_mem, store_reg(.a)}, {2, 2}}, // 2clocks
  {"ld [word %4x], sp", B("00001000"), {next, next, stash, load_reg(.spl), write_mem, inc_stash, load_reg(.sph), write_mem}, {5, 5}}, // 5clocks
  
  {"inc %v",     B("00w_0011"), {load_reg(.r16), alu(.INC), store_reg(.r16)}, {2, 2}}, // 2clocks
  {"dec %v",     B("00w_1011"), {load_reg(.r16), alu(.DEC), store_reg(.r16)}, {2, 2}}, // 2clocks
  {"add hl, %v", B("00w_1001"), {load_reg(.r16), stash, load_reg(.hl), alu2(.ADD), store_reg(.hl)}, {2, 2}}, // 2clocks
  
  {"inc %v", B("00r__100"), {load_reg(.r8), alu(.INC), store_reg(.r8)}, {1, 3}}, // 1-3clocks
  {"dec %v", B("00r__101"), {load_reg(.r8), alu(.DEC), store_reg(.r8)}, {1, 3}}, // 1-3clocks
  
  {"ld %v, byte %2x", B("00r__110"), {next, store_reg(.r8)}, {2, 3}}, // 2clocks
  
  {"rlca", B("00000111"), {load_reg(.a), alu(.RLC, set_flags = false), store_reg(.a)}, {1, 1}}, // 1clocks
  {"rrca", B("00001111"), {load_reg(.a), alu(.RRC, set_flags = false), store_reg(.a)}, {1, 1}}, // 1clocks
  {"rla",  B("00010111"), {load_reg(.a), alu(.RL, set_flags = false),  store_reg(.a)}, {1, 1}}, // 1clocks
  {"rra",  B("00011111"), {load_reg(.a), alu(.RR, set_flags = false),  store_reg(.a)}, {1, 1}}, // 1clocks
  
  {"daa", B("00100111"), {load_reg(.a), alu(.DAA), store_reg(.a)}, {1, 1}}, // 1clocks
  {"cpl", B("00101111"), {load_reg(.a), alu(.CPL), store_reg(.a)}, {1, 1}}, // 1clocks
  {"scf", B("00110111"), {alu(.SCF)}, {1, 1}}, // 1clocks
  {"ccf", B("00111111"), {alu(.CCF)}, {1, 1}}, // 1clocks
  
  {"jr ~%2x",      B("00011000"), {next, stash,                  load_reg(.pc), alu2(.SIGNED_ADD, set_flags = false), store_reg(.pc)}, {3, 3}}, // 3clocks 
  {"jr %v, ~%2x", B("001c_000"), {next, stash, check_condition, load_reg(.pc), alu2(.SIGNED_ADD, set_flags = false), store_reg(.pc)}, {2, 3}}, // 2-3clocks
  
  {"stop", B("00010000"), {stop}, {0, 0}},
  
  // Block 1
  // The order of these following two instructions is important!
  {"halt", B("01110110"), {halt}, {0,0}}, // ?clocks
  
  {"ld %v, %v", B("01d__s__"), {load_reg(.s8), store_reg(.d8)}, {1, 2}}, // 1-2clocks
  
  // Block 2
  {"add a, %v", B("10000r__"), {load_reg(.r8), stash, load_reg(.a), alu2(.ADD), store_reg(.a)}, {1, 2}}, // 1-2clocks
  {"adc a, %v", B("10001r__"), {load_reg(.r8), stash, load_reg(.a), alu2(.ADC), store_reg(.a)}, {1, 2}}, // 1-2clocks
  {"sub a, %v", B("10010r__"), {load_reg(.r8), stash, load_reg(.a), alu2(.SUB), store_reg(.a)}, {1, 2}}, // 1-2clocks
  {"sbc a, %v", B("10011r__"), {load_reg(.r8), stash, load_reg(.a), alu2(.SBC), store_reg(.a)}, {1, 2}}, // 1-2clocks
  {"and a, %v", B("10100r__"), {load_reg(.r8), stash, load_reg(.a), alu2(.AND), store_reg(.a)}, {1, 2}}, // 1-2clocks
  {"xor a, %v", B("10101r__"), {load_reg(.r8), stash, load_reg(.a), alu2(.XOR), store_reg(.a)}, {1, 2}}, // 1-2clocks
  {"or  a, %v", B("10110r__"), {load_reg(.r8), stash, load_reg(.a), alu2(.OR),  store_reg(.a)}, {1, 2}}, // 1-2clocks
  {"cp  a, %v", B("10111r__"), {load_reg(.r8), stash, load_reg(.a), alu2(.CP),  store_reg(.a)}, {1, 2}}, // 1-2clocks
  
  // Block 3
  {"xxx", B("11010011"), {illegal}, {1, 1}}, // 1clocks
  {"xxx", B("11011011"), {illegal}, {1, 1}}, // 1clocks
  {"xxx", B("11011101"), {illegal}, {1, 1}}, // 1clocks
  {"xxx", B("11100011"), {illegal}, {1, 1}}, // 1clocks
  {"xxx", B("11100100"), {illegal}, {1, 1}}, // 1clocks
  {"xxx", B("11101011"), {illegal}, {1, 1}}, // 1clocks
  {"xxx", B("11101100"), {illegal}, {1, 1}}, // 1clocks
  {"xxx", B("11101101"), {illegal}, {1, 1}}, // 1clocks
  {"xxx", B("11110100"), {illegal}, {1, 1}}, // 1clocks
  {"xxx", B("11111100"), {illegal}, {1, 1}}, // 1clocks
  {"xxx", B("11111101"), {illegal}, {1, 1}}, // 1clocks
  
  {"add a, byte %2x", B("11000110"), {next, stash, load_reg(.a), alu2(.ADD), store_reg(.a)}, {2, 2}}, // 2clocks
  {"adc a, byte %2x", B("11001110"), {next, stash, load_reg(.a), alu2(.ADC), store_reg(.a)}, {2, 2}}, // 2clocks
  {"sub a, byte %2x", B("11010110"), {next, stash, load_reg(.a), alu2(.SUB), store_reg(.a)}, {2, 2}}, // 2clocks
  {"sbc a, byte %2x", B("11011110"), {next, stash, load_reg(.a), alu2(.SBC), store_reg(.a)}, {2, 2}}, // 2clocks
  {"and a, byte %2x", B("11100110"), {next, stash, load_reg(.a), alu2(.AND), store_reg(.a)}, {2, 2}}, // 2clocks
  {"xor a, byte %2x", B("11101110"), {next, stash, load_reg(.a), alu2(.XOR), store_reg(.a)}, {2, 2}}, // 2clocks
  {"or  a, byte %2x", B("11110110"), {next, stash, load_reg(.a), alu2(.OR),  store_reg(.a)}, {2, 2}}, // 2clocks
  {"cp  a, byte %2x", B("11111110"), {next, stash, load_reg(.a), alu2(.CP),  store_reg(.a)}, {2, 2}}, // 2clocks
  
  {"ret %v", B("110c_000"), {clock, check_condition, clock, pop, pop, store_reg(.pc)}, {2, 5}}, // 2-5clocks
  {"ret",    B("11001001"), {clock, pop, pop, store_reg(.pc)}, {4, 4}}, // 4clocks
  {"reti",   B("11011001"), {clock, pop, pop, store_reg(.pc), set_i}, {4, 4}}, // 4clocks
  
  {"jp %v, word %4x", B("110c_010"), {next, next, check_condition, store_reg(.pc)}, {3, 4}}, // 3-4clocks
  {"jp word %4x",     B("11000011"), {next, next, store_reg(.pc), clock}, {4, 4}}, // 4clocks
  {"jp hl",           B("11101001"), {load_reg(.hl), store_reg(.pc)}, {1, 1}}, // 1clocks
  
  {"call %v, word $%4x", B("110c_100"), {next, next, stash, check_condition, load_reg(.pc), clock, push, push, unstash, store_reg(.pc)}, {3, 6}}, // 3-6clocks
  {"call word $%4x",     B("11001101"), {next, next, stash,                  load_reg(.pc), clock, push, push, unstash, store_reg(.pc)}, {6, 6}}, // 6clocks
  
  {"rst %2x", B("11t__111"), {load_reg(.pc), push, push, rst}, {4, 4}}, // 4clocks
  
  {"pop  %v", B("11k_0001"), {pop, pop, store_reg(.r16stk)}, {3, 3}}, // 3clocks
  {"push %v", B("11k_0101"), {load_reg(.r16stk), clock, push, push}, {4, 4}}, // 4clocks
  
  {"", B("11001011"), {prefix}, {1, 1}}, // 1clocks
  
  {"ldh [c],  a",       B("11100010"), {load_reg(.c), set_msb, stash, load_reg(.a), write_mem}, {2, 2}}, // 2clocks
  {"ldh [byte %2x], a", B("11100000"), {next,         set_msb, stash, load_reg(.a), write_mem}, {3, 3}}, // 3clocks
  {"ld [word %4x], a",  B("11101010"), {next,         next,    stash, load_reg(.a), write_mem}, {4, 4}}, // 4clocks
  {"ldh a, [c]",        B("11110010"), {load_reg(.c), set_msb, stash, read_mem, store_reg(.a)}, {2, 2}}, // 2clocks
  {"ldh a, [byte %2x]", B("11110000"), {next,         set_msb, stash, read_mem, store_reg(.a)}, {3, 3}}, // 3clocks
  {"ld a, [word %4x]",  B("11111010"), {next,         next,    stash, read_mem, store_reg(.a)}, {4, 4}}, // 4clocks
  
  
  {"add sp, byte %v",       B("11101000"), {next, stash, load_reg(.sp), alu2(.SIGNED_ADD), clock, store_reg(.sp)}, {4, 4}}, // 4clocks
  {"ld hl, sp + byte %2x",  B("11111000"), {next, stash, load_reg(.sp), alu2(.SIGNED_ADD), store_reg(.hl)}, {3, 3}}, // 3clocks
  {"ld sp, hl",             B("11111001"), {load_reg(.hl), store_reg(.sp), clock}, {2, 2}}, // 2clocks

  {"di", B("11110011"), {clear_i}, {1, 1}}, // 1clocks
  {"ei", B("11111011"), {set_i},   {1, 1}}, // 1clocks
}

@(private)
opcode_table_prefixed_v2 := [?]Op_Encoding_V2{ // +1 clocks
  {"rlc %v",  B("00000r__"), {load_reg(.r8), alu(.RLC),  store_reg(.r8)}, {2, 4}}, // 1-3clocks
  {"rrc %v",  B("00001r__"), {load_reg(.r8), alu(.RRC),  store_reg(.r8)}, {2, 4}}, // 1-3clocks
  {"rl %v",   B("00010r__"), {load_reg(.r8), alu(.RL),   store_reg(.r8)}, {2, 4}}, // 1-3clocks
  {"rr %v",   B("00011r__"), {load_reg(.r8), alu(.RR),   store_reg(.r8)}, {2, 4}}, // 1-3clocks
  {"sla %v",  B("00100r__"), {load_reg(.r8), alu(.SLA),  store_reg(.r8)}, {2, 4}}, // 1-3clocks
  {"sra %v",  B("00101r__"), {load_reg(.r8), alu(.SRA),  store_reg(.r8)}, {2, 4}}, // 1-3clocks
  {"srl %v",  B("00111r__"), {load_reg(.r8), alu(.SRL),  store_reg(.r8)}, {2, 4}}, // 1-3clocks
  {"swap %v", B("00110r__"), {load_reg(.r8), alu(.SWAP), store_reg(.r8)}, {2, 4}}, // 1-3clocks
  
  {"bit %v, %v,", B("01i__r__"), {load_reg(.r8), alu(.BIT)}, {2, 3}}, // 1-3clocks
  {"res %v, %v,", B("10i__r__"), {load_reg(.r8), alu(.RES), store_reg(.r8)}, {2, 4}}, // 1-3clocks
  {"set %v, %v,", B("11i__r__"), {load_reg(.r8), alu(.SET), store_reg(.r8)}, {2, 4}}, // 1-3clocks
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

write_mem :: Command{type = .write}
read_mem  :: Command{type = .read}

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