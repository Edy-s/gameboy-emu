package memory_regions

TIMER_DIV     :: 0xFF04
TIMER_COUNT   :: 0xFF05
TIMER_MODULO  :: 0xFF06
TIMER_CONTROL :: 0xFF07
Timer_Control_Reg :: bit_field u8 {
  clock_select: enum u8 {M_256, M_4, M_16, M_64} | 2,
  enabled: bool | 1
}

OAM_START :: 0xFE00
OAM_END   :: 0xFE9F
OAM_DMA_REGISTER :: 0xFF46

INTERRUPT_TOGGLES :: 0xFFFF
INTERRUPT_FLAGS   :: 0xFF0F
Interrupt_Flag_Type :: enum {
  VBlank,
  LCD,
  Timer,
  Serial,
  Joypad,
}
Interrupt_Flags :: bit_set[Interrupt_Flag_Type; u8]


LCD_CONTROL      :: 0xFF40
LCD_Control_Byte :: bit_set[enum {
  bg_priority,
  obj_enable,
  obj_size,
  bg_tile_map_area,
  bg_window_tile_data_area,
  window_enable,
  window_tile_map_area,
  LCD_enable
}; u8]

LCD_STATUS  :: 0xFF41
LCD_Y_COORD :: 0xFF44
LCD_Y_COORD_COMPARE :: 0xFF45

VIDEO_RAM_START :: 0x8000
VIDEO_RAM_END   :: 0x9FFF

// TILE_DATA_OFFSET :: 0x0000
TILE_MAP_OFFSET :: 0x1800

TILE_DATA  :: 0x8000
BG_TILEMAP :: 0x9800

BACKGROUND_X :: 0xFF43
BACKGROUND_Y :: 0xFF42

WINDOW_X :: 0xFF4B
WINDOW_Y :: 0xFF4A