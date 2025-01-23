package memory_regions

OAM_START :: 0xFE00
OAM_END   :: 0xFE9F
OAM_DMA_REGISTER :: 0xFF46

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