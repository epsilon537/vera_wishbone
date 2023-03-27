//`default_nettype none

module top(
    input  wire       clk,
    input  wire       reset,

    input wire [31:0]  wb_adr,
	input wire [31:0]  wb_dat_w,
	output wire [31:0] wb_dat_r,
	input wire [3:0]   wb_sel,
    output wire        wb_stall,
	input wire         wb_cyc,
	input wire         wb_stb,
	output wire        wb_ack,
	input wire         wb_we,
	output wire        wb_err,

    // External bus interface
    output wire       irq_n,  /* IRQ */

    // VGA interface
    output reg  [3:0] vga_r       /* synthesis syn_useioff = 1 */,
    output reg  [3:0] vga_g       /* synthesis syn_useioff = 1 */,
    output reg  [3:0] vga_b       /* synthesis syn_useioff = 1 */,
    output reg        vga_hsync   /* synthesis syn_useioff = 1 */,
    output reg        vga_vsync   /* synthesis syn_useioff = 1 */

`ifdef VERA_SPI
    ,
    // SPI interface
    output wire       spi_sck,
    output wire       spi_mosi,
    input  wire       spi_miso,
    output wire       spi_ssel_n_sd
`endif /*VERA_SPI*/

`ifdef VERA_AUDIO
    ,
    // Audio output
    output wire       audio_lrck,
    output wire       audio_bck,
    output wire       audio_data
`endif /*VERA_AUDIO*/
    );
    
    //////////////////////////////////////////////////////////////////////////
    // Bus accessible registers
    //////////////////////////////////////////////////////////////////////////
    reg [31:0] vram_dat_r;
    reg [16:0] vram_addr_0_r,                 vram_addr_0_next;
    reg [16:0] vram_addr_1_r,                 vram_addr_1_next;
    reg  [3:0] vram_addr_incr_0_r,            vram_addr_incr_0_next;
    reg  [3:0] vram_addr_incr_1_r,            vram_addr_incr_1_next;
    reg        vram_addr_decr_0_r,            vram_addr_decr_0_next;
    reg        vram_addr_decr_1_r,            vram_addr_decr_1_next;
    reg        vram_addr_select_r,            vram_addr_select_next;
    reg  [7:0] vram_data0_r,                  vram_data0_next;
    reg  [7:0] vram_data1_r,                  vram_data1_next;
    reg        dc_select_r,                   dc_select_next;
    reg  [1:0] sprite_bank_select_r,          sprite_bank_select_next;
    reg        fpga_reconfigure_r,            fpga_reconfigure_next;
    reg        irq_enable_vsync_r,            irq_enable_vsync_next;
    reg        irq_enable_line_r,             irq_enable_line_next;
    reg        irq_enable_sprite_collision_r, irq_enable_sprite_collision_next;
`ifdef VERA_AUDIO
    reg        irq_enable_audio_fifo_low_r,   irq_enable_audio_fifo_low_next;
`endif    
    reg        irq_status_vsync_r,            irq_status_vsync_next;
    reg        irq_status_line_r,             irq_status_line_next;
    reg        irq_status_sprite_collision_r, irq_status_sprite_collision_next;
    reg  [8:0] irq_line_r,                    irq_line_next;
    reg        sprites_enabled_r,             sprites_enabled_next;
    reg        l0_enabled_r,                  l0_enabled_next;
    reg        l1_enabled_r,                  l1_enabled_next;

    reg        chroma_disable_r,              chroma_disable_next;
    reg  [7:0] dc_hscale_r,                   dc_hscale_next;
    reg  [7:0] dc_vscale_r,                   dc_vscale_next;
    reg  [7:0] dc_border_color_r,             dc_border_color_next;
    reg  [9:0] dc_active_hstart_r,            dc_active_hstart_next;
    reg  [9:0] dc_active_hstop_r,             dc_active_hstop_next;
    reg  [8:0] dc_active_vstart_r,            dc_active_vstart_next;
    reg  [8:0] dc_active_vstop_r,             dc_active_vstop_next;

    reg  [1:0] l0_color_depth_r,              l0_color_depth_next;
    reg        l0_bitmap_mode_r,              l0_bitmap_mode_next;
    reg        l0_attr_mode_r,                l0_attr_mode_next;
    reg        l0_tile_height_r,              l0_tile_height_next;
    reg        l0_tile_width_r,               l0_tile_width_next;
    reg  [1:0] l0_map_height_r,               l0_map_height_next;
    reg  [1:0] l0_map_width_r,                l0_map_width_next;
    reg  [7:0] l0_map_baseaddr_r,             l0_map_baseaddr_next;
    reg  [7:0] l0_tile_baseaddr_r,            l0_tile_baseaddr_next;
    reg [11:0] l0_hscroll_r,                  l0_hscroll_next;
    reg [11:0] l0_vscroll_r,                  l0_vscroll_next;

    reg  [1:0] l1_color_depth_r,              l1_color_depth_next;
    reg        l1_bitmap_mode_r,              l1_bitmap_mode_next;
    reg        l1_attr_mode_r,                l1_attr_mode_next;
    reg        l1_tile_height_r,              l1_tile_height_next;
    reg        l1_tile_width_r,               l1_tile_width_next;
    reg  [1:0] l1_map_height_r,               l1_map_height_next;
    reg  [1:0] l1_map_width_r,                l1_map_width_next;
    reg  [7:0] l1_map_baseaddr_r,             l1_map_baseaddr_next;
    reg  [7:0] l1_tile_baseaddr_r,            l1_tile_baseaddr_next;
    reg [11:0] l1_hscroll_r,                  l1_hscroll_next;
    reg [11:0] l1_vscroll_r,                  l1_vscroll_next;

    reg  [1:0] video_output_mode_r,           video_output_mode_next;

`ifdef VERA_AUDIO
    reg  [7:0] audio_pcm_sample_rate_r,       audio_pcm_sample_rate_next;
    reg        audio_mode_stereo_r,           audio_mode_stereo_next;
    reg        audio_mode_16bit_r,            audio_mode_16bit_next;
    reg        audio_fifo_reset_r,            audio_fifo_reset_next;
    wire       audio_fifo_full;
    reg  [3:0] audio_pcm_volume_r,            audio_pcm_volume_next;
    reg  [7:0] audio_fifo_wrdata_r,           audio_fifo_wrdata_next;
    reg        audio_fifo_write_r,            audio_fifo_write_next;
`endif
    wire [3:0] sprite_collisions;
    wire       current_field;

`ifdef VERA_AUDIO
    wire       audio_fifo_low;
    wire       audio_fifo_empty;
`endif
    wire       sprcol_irq;
    wire       vblank_pulse;
    wire       line_irq;
    wire [8:0] scanline;

 `ifdef VERA_SPI
    reg        spi_select_r,                  spi_select_next;
    reg        spi_slow_r,                    spi_slow_next;
    reg        spi_autotx_r,                  spi_autotx_next;
    reg  [7:0] spi_txdata;
    reg        spi_txstart;
    wire       spi_busy;
    wire [7:0] spi_rxdata;
`endif

    /*Register read interface*/
    reg [7:0] rddata;
    always @* begin
        rddata = 8'h00;
        
        if (wb_stb && !wb_we) begin
            case (wb_adr[6:2])
                5'h00: rddata = vram_addr_select_r ? vram_addr_1_r[7:0] : vram_addr_0_r[7:0];
                5'h01: rddata = vram_addr_select_r ? vram_addr_1_r[15:8] : vram_addr_0_r[15:8];
                5'h02: rddata = vram_addr_select_r ? {vram_addr_incr_1_r, vram_addr_decr_1_r, 2'b0, vram_addr_1_r[16]} : {vram_addr_incr_0_r, vram_addr_decr_0_r, 2'b0, vram_addr_0_r[16]};
                5'h03: rddata = vram_data0_r;
                5'h04: rddata = vram_data1_r;
                5'h05: rddata = {4'b0, sprite_bank_select_r, dc_select_r, vram_addr_select_r};

                5'h06: rddata = {irq_line_r[8], scanline[8], 2'b0,
`ifdef VERA_AUDIO
                                irq_enable_audio_fifo_low_r,
`else
                                1'b0,
`endif                                
                                irq_enable_sprite_collision_r, irq_enable_line_r, irq_enable_vsync_r};
                5'h07: rddata = {sprite_collisions,
`ifdef VERA_AUDIO
                                audio_fifo_low, 
`else
                                1'b0,
`endif                                                                             
                                irq_status_sprite_collision_r, irq_status_line_r, irq_status_vsync_r};
                5'h08: rddata = scanline[7:0];

                5'h09: begin
                    if (dc_select_r == 0) begin
                        rddata = {current_field, sprites_enabled_r, l1_enabled_r, l0_enabled_r, 1'b0, chroma_disable_r, video_output_mode_r};
                    end else begin
                        rddata = dc_active_hstart_r[9:2];
                    end
                end
                5'h0A: begin
                    if (dc_select_r == 0) begin
                        rddata = dc_hscale_r;
                    end else begin
                        rddata = dc_active_hstop_r[9:2];
                    end
                end
                5'h0B: begin
                    if (dc_select_r == 0) begin
                        rddata = dc_vscale_r;
                    end else begin
                        rddata = dc_active_vstart_r[8:1];
                    end
                end
                5'h0C: begin
                    if (dc_select_r == 0) begin
                        rddata = dc_border_color_r;
                    end else begin
                        rddata = dc_active_vstop_r[8:1];
                    end
                end

                5'h0D: rddata = {l0_map_height_r, l0_map_width_r, l0_attr_mode_r, l0_bitmap_mode_r, l0_color_depth_r};
                5'h0E: rddata = l0_map_baseaddr_r;
                5'h0F: rddata = {l0_tile_baseaddr_r[7:2], l0_tile_height_r, l0_tile_width_r};
                5'h10: rddata = l0_hscroll_r[7:0];
                5'h11: rddata = {4'b0, l0_hscroll_r[11:8]};
                5'h12: rddata = l0_vscroll_r[7:0];
                5'h13: rddata = {4'b0, l0_vscroll_r[11:8]};

                5'h14: rddata = {l1_map_height_r, l1_map_width_r, l1_attr_mode_r, l1_bitmap_mode_r, l1_color_depth_r};
                5'h15: rddata = l1_map_baseaddr_r;
                5'h16: rddata = {l1_tile_baseaddr_r[7:2], l1_tile_height_r, l1_tile_width_r};
                5'h17: rddata = l1_hscroll_r[7:0];
                5'h18: rddata = {4'b0, l1_hscroll_r[11:8]};
                5'h19: rddata = l1_vscroll_r[7:0];
                5'h1A: rddata = {4'b0, l1_vscroll_r[11:8]};
`ifdef VERA_AUDIO
                5'h1B: rddata = {audio_fifo_full, audio_fifo_empty, audio_mode_16bit_r, audio_mode_stereo_r, audio_pcm_volume_r};
                5'h1C: rddata = audio_pcm_sample_rate_r;
                5'h1D: rddata = 8'h00;
`endif
 `ifdef VERA_SPI
                5'h1E: rddata = spi_rxdata;
                5'h1F: rddata = {spi_busy, 4'b0, spi_autotx_r, spi_slow_r, spi_select_r};
`endif
                default: rddata = 8'h00;
            endcase
        end
    end

    assign wb_dat_r = (wb_adr < 32'h1000) ? {24'b0,rddata} : vram_dat_r;

    wire [3:0] irq_enable = {
`ifdef VERA_AUDIO
        irq_enable_audio_fifo_low_r,
`else
        1'b0,
`endif
        irq_enable_sprite_collision_r, irq_enable_line_r, irq_enable_vsync_r};
    wire [3:0] irq_status = {
`ifdef VERA_AUDIO
        audio_fifo_low,
`else
        1'b0,
`endif                
        irq_status_sprite_collision_r, irq_status_line_r, irq_status_vsync_r};

    assign irq_n = (irq_status & irq_enable) == 0;

    /*Register writes and RAM reads and writes*/

    reg [4:0] rdaddr_r;
    reg [4:0] wraddr_r;
    reg [7:0] wrdata_r;
    reg do_read, do_write;
    reg spr_pal_ram_wb_ack_r;

    always @(posedge clk) begin
        do_read <= 1'b0;
        do_write <= 1'b0;
        if (wb_stb && wb_we && (wb_adr < 32'h1000)) begin
            wrdata_r <= wb_dat_w[7:0];
            wraddr_r <= wb_adr[6:2];
            do_write <= 1'b1;
        end
        if (wb_stb && !wb_we && (wb_adr < 32'h1000)) begin
            rdaddr_r <= wb_adr[6:2];
            do_read <= 1'b1;
        end
    end

    assign wb_ack = (do_read | do_write | ib_ack | spr_pal_ram_wb_ack_r) & wb_cyc;
    assign wb_err = 1'b0;
    assign wb_stall = !wb_cyc ? 1'b0 : !wb_ack;

    wire [4:0] access_addr = do_write ? wraddr_r : rdaddr_r;
    wire [7:0] write_data  = wrdata_r;

    // Decode increment value
    wire [3:0] incr_regval = (access_addr == 5'h03) ? vram_addr_incr_0_r : vram_addr_incr_1_r;
    reg [9:0] increment;
    always @* case (incr_regval)
        4'h0: increment = 'd0;
        4'h1: increment = 'd1;
        4'h2: increment = 'd2;
        4'h3: increment = 'd4;
        4'h4: increment = 'd8;
        4'h5: increment = 'd16;
        4'h6: increment = 'd32;
        4'h7: increment = 'd64;
        4'h8: increment = 'd128;
        4'h9: increment = 'd256;
        4'hA: increment = 'd512;
        4'hB: increment = 'd40;
        4'hC: increment = 'd80;
        4'hD: increment = 'd160;
        4'hE: increment = 'd320;
        4'hF: increment = 'd640;
    endcase

    wire       ib_ack;
    reg [16:0] ib_addr_r,      ib_addr_next;
    reg  [7:0] ib_wrdata_r,    ib_wrdata_next;
    reg        ib_write_r,     ib_write_next;

    reg        fetch_ahead_r,  fetch_ahead_next;
    reg        fetch_ahead_port_r,  fetch_ahead_port_next;

    wire [16:0] vram_addr             = (access_addr == 5'h03) ? vram_addr_0_r : vram_addr_1_r;
    wire        vram_addr_decr        = (access_addr == 5'h03) ? vram_addr_decr_0_r : vram_addr_decr_1_r;
    wire [16:0] vram_addr_incremented = vram_addr + increment;
    wire [16:0] vram_addr_decremented = vram_addr - increment;
    wire [16:0] vram_addr_new         = vram_addr_decr ? vram_addr_decremented : vram_addr_incremented;

    always @* begin
        vram_addr_0_next                 = vram_addr_0_r;
        vram_addr_1_next                 = vram_addr_1_r;
        vram_addr_incr_0_next            = vram_addr_incr_0_r;
        vram_addr_incr_1_next            = vram_addr_incr_1_r;
        vram_addr_decr_0_next            = vram_addr_decr_0_r;
        vram_addr_decr_1_next            = vram_addr_decr_1_r;
        vram_addr_select_next            = vram_addr_select_r;
        vram_data0_next                  = vram_data0_r;
        vram_data1_next                  = vram_data1_r;
        dc_select_next                   = dc_select_r;
        sprite_bank_select_next          = sprite_bank_select_r;
        fpga_reconfigure_next            = fpga_reconfigure_r;
`ifdef VERA_AUDIO
        irq_enable_audio_fifo_low_next   = irq_enable_audio_fifo_low_r;
`endif        
        irq_enable_vsync_next            = irq_enable_vsync_r;
        irq_enable_line_next             = irq_enable_line_r;
        irq_enable_sprite_collision_next = irq_enable_sprite_collision_r;
        irq_status_vsync_next            = irq_status_vsync_r;
        irq_status_line_next             = irq_status_line_r;
        irq_status_sprite_collision_next = irq_status_sprite_collision_r;
        irq_line_next                    = irq_line_r;
        sprites_enabled_next             = sprites_enabled_r;
        l0_enabled_next                  = l0_enabled_r;
        l1_enabled_next                  = l1_enabled_r;
        chroma_disable_next              = chroma_disable_r;
        dc_hscale_next                   = dc_hscale_r;
        dc_vscale_next                   = dc_vscale_r;
        dc_border_color_next             = dc_border_color_r;
        dc_active_hstart_next            = dc_active_hstart_r;
        dc_active_hstop_next             = dc_active_hstop_r;
        dc_active_vstart_next            = dc_active_vstart_r;
        dc_active_vstop_next             = dc_active_vstop_r;
        l0_color_depth_next              = l0_color_depth_r;
        l0_bitmap_mode_next              = l0_bitmap_mode_r;
        l0_attr_mode_next                = l0_attr_mode_r;
        l0_tile_height_next              = l0_tile_height_r;
        l0_tile_width_next               = l0_tile_width_r;
        l0_map_height_next               = l0_map_height_r;
        l0_map_width_next                = l0_map_width_r;
        l0_map_baseaddr_next             = l0_map_baseaddr_r;
        l0_tile_baseaddr_next            = l0_tile_baseaddr_r;
        l0_hscroll_next                  = l0_hscroll_r;
        l0_vscroll_next                  = l0_vscroll_r;
        l1_color_depth_next              = l1_color_depth_r;
        l1_bitmap_mode_next              = l1_bitmap_mode_r;
        l1_attr_mode_next                = l1_attr_mode_r;
        l1_tile_height_next              = l1_tile_height_r;
        l1_tile_width_next               = l1_tile_width_r;
        l1_map_height_next               = l1_map_height_r;
        l1_map_width_next                = l1_map_width_r;
        l1_map_baseaddr_next             = l1_map_baseaddr_r;
        l1_tile_baseaddr_next            = l1_tile_baseaddr_r;
        l1_hscroll_next                  = l1_hscroll_r;
        l1_vscroll_next                  = l1_vscroll_r;
        video_output_mode_next           = video_output_mode_r;

`ifdef VERA_AUDIO
        audio_pcm_sample_rate_next       = audio_pcm_sample_rate_r;
        audio_mode_stereo_next           = audio_mode_stereo_r;
        audio_mode_16bit_next            = audio_mode_16bit_r;
        audio_fifo_reset_next            = 0;
        audio_pcm_volume_next            = audio_pcm_volume_r;
        audio_fifo_wrdata_next           = audio_fifo_wrdata_r;
        audio_fifo_write_next            = 0;
`endif
 `ifdef VERA_SPI
        spi_select_next                  = spi_select_r;
        spi_slow_next                    = spi_slow_r;
        spi_autotx_next                  = spi_autotx_r;
`endif
        ib_addr_next                     = ib_addr_r;
        ib_wrdata_next                   = ib_wrdata_r;
        ib_write_next                    = ib_write_r;

        fetch_ahead_port_next            = fetch_ahead_port_r;
        fetch_ahead_next                 = 0;

`ifdef VERA_SPI
        spi_txdata                       = write_data;
        spi_txstart                      = 0;
`endif

        if (do_write) begin
            case (access_addr)
                5'h00: begin
                    if (vram_addr_select_r) begin
                        vram_addr_1_next[7:0] = write_data;
                    end else begin
                        vram_addr_0_next[7:0] = write_data;
                    end

                    fetch_ahead_port_next = vram_addr_select_r;
                    fetch_ahead_next = 1;
                end
                5'h01: begin
                    if (vram_addr_select_r) begin
                        vram_addr_1_next[15:8] = write_data;
                    end else begin
                        vram_addr_0_next[15:8] = write_data;
                    end

                    fetch_ahead_port_next = vram_addr_select_r;
                    fetch_ahead_next = 1;
                end
                5'h02: begin
                    if (vram_addr_select_r) begin
                        vram_addr_incr_1_next = write_data[7:4];
                        vram_addr_decr_1_next = write_data[3];
                        vram_addr_1_next[16]  = write_data[0];
                    end else begin
                        vram_addr_incr_0_next = write_data[7:4];
                        vram_addr_decr_0_next = write_data[3];
                        vram_addr_0_next[16]  = write_data[0];
                    end

                    fetch_ahead_port_next = vram_addr_select_r;
                    fetch_ahead_next = 1;
                end
                5'h03: begin
                end
                5'h04: begin
                end
                5'h05: begin
                    fpga_reconfigure_next   = write_data[7];
                    sprite_bank_select_next = write_data[3:2];
                    dc_select_next          = write_data[1];
                    vram_addr_select_next   = write_data[0];
                end

                5'h06: begin
                    irq_line_next[8]                 = write_data[7];
`ifdef VERA_AUDIO
                    irq_enable_audio_fifo_low_next   = write_data[3];
`endif                    
                    irq_enable_sprite_collision_next = write_data[2];
                    irq_enable_line_next             = write_data[1];
                    irq_enable_vsync_next            = write_data[0];
                end
                5'h07: begin
                    // Clear status bits
                    irq_status_sprite_collision_next = irq_status_sprite_collision_r & !write_data[2];
                    irq_status_line_next             = irq_status_line_r             & !write_data[1];
                    irq_status_vsync_next            = irq_status_vsync_r            & !write_data[0];
                end
                5'h08: irq_line_next[7:0] = write_data;

                5'h09: begin
                    if (dc_select_r == 0) begin
                        sprites_enabled_next   = write_data[6];
                        l1_enabled_next        = write_data[5];
                        l0_enabled_next        = write_data[4];
                        chroma_disable_next    = write_data[2];
                        video_output_mode_next = write_data[1:0];
                    end else begin
                        dc_active_hstart_next[9:2] = write_data;
                        dc_active_hstart_next[1:0] = 0;
                    end
                end
                5'h0A: begin
                    if (dc_select_r == 0) begin
                        dc_hscale_next            = write_data;
                    end else begin
                        dc_active_hstop_next[9:2] = write_data;
                        dc_active_hstop_next[1:0] = 0;
                    end
                end
                5'h0B: begin
                    if (dc_select_r == 0) begin
                        dc_vscale_next             = write_data;
                    end else begin
                        dc_active_vstart_next[8:1] = write_data;
                        dc_active_vstart_next[0]   = 0;
                    end
                end
                5'h0C: begin
                    if (dc_select_r == 0) begin
                        dc_border_color_next      = write_data;
                    end else begin
                        dc_active_vstop_next[8:1] = write_data;
                        dc_active_vstop_next[0]   = 0;
                    end
                end

                5'h0D: begin
                    l0_map_height_next  = write_data[7:6];
                    l0_map_width_next   = write_data[5:4];
                    l0_attr_mode_next   = write_data[3];
                    l0_bitmap_mode_next = write_data[2];
                    l0_color_depth_next = write_data[1:0];
                end
                5'h0E: l0_map_baseaddr_next = write_data;
                5'h0F: begin
                    l0_tile_baseaddr_next[7:2] = write_data[7:2];
                    l0_tile_baseaddr_next[1:0] = 0;

                    l0_tile_height_next = write_data[1];
                    l0_tile_width_next  = write_data[0];
                end
                5'h10: l0_hscroll_next[7:0]  = write_data;
                5'h11: l0_hscroll_next[11:8] = write_data[3:0];
                5'h12: l0_vscroll_next[7:0]  = write_data;
                5'h13: l0_vscroll_next[11:8] = write_data[3:0];

                5'h14: begin
                    l1_map_height_next  = write_data[7:6];
                    l1_map_width_next   = write_data[5:4];
                    l1_attr_mode_next   = write_data[3];
                    l1_bitmap_mode_next = write_data[2];
                    l1_color_depth_next = write_data[1:0];
                end
                5'h15: l1_map_baseaddr_next = write_data;
                5'h16: begin
                    l1_tile_baseaddr_next[7:2] = write_data[7:2];
                    l1_tile_baseaddr_next[1:0] = 0;

                    l1_tile_height_next = write_data[1];
                    l1_tile_width_next  = write_data[0];
                end
                5'h17: l1_hscroll_next[7:0]  = write_data;
                5'h18: l1_hscroll_next[11:8] = write_data[3:0];
                5'h19: l1_vscroll_next[7:0]  = write_data;
                5'h1A: l1_vscroll_next[11:8] = write_data[3:0];

`ifdef VERA_AUDIO
                5'h1B: begin
                    audio_fifo_reset_next       = write_data[7];
                    audio_mode_16bit_next       = write_data[5];
                    audio_mode_stereo_next      = write_data[4];
                    audio_pcm_volume_next       = write_data[3:0];
                end
                5'h1C: audio_pcm_sample_rate_next = write_data;
                5'h1D: begin
                    audio_fifo_wrdata_next = write_data;
                    audio_fifo_write_next  = 1;
                end
`endif
 `ifdef VERA_SPI
                5'h1E: spi_txstart = 1;
                5'h1F: begin
                    spi_autotx_next = write_data[2];
                    spi_slow_next   = write_data[1];
                    spi_select_next = write_data[0];
                end
`endif                
                default: begin
                end
            endcase
        end

 `ifdef VERA_SPI
        // SPI auto-tx function
        if (spi_autotx_r && access_addr == 5'h1E && do_read) begin
            spi_txdata = 8'hFF;
            spi_txstart = 1;
        end
`endif
        if (sprcol_irq) begin
            irq_status_sprite_collision_next = 1;
        end
        if (line_irq) begin
            irq_status_line_next = 1;
        end
        if (vblank_pulse) begin
            irq_status_vsync_next = 1;
        end

        if (fetch_ahead_r) begin
            ib_addr_next      = fetch_ahead_port_r ? vram_addr_1_r : vram_addr_0_r;
            ib_write_next     = 0;
        end

        if ((do_write || do_read) && (access_addr == 5'h03 || access_addr == 5'h04)) begin
            ib_wrdata_next = write_data;
            ib_write_next  = do_write;

            if (do_write) begin
                ib_addr_next = access_addr == 5'h03 ? vram_addr_0_r : vram_addr_1_r;
            end

            if (access_addr == 5'h03) begin
                fetch_ahead_port_next = 0;
                vram_addr_0_next = vram_addr_new;
            end else begin
                fetch_ahead_port_next = 1;
                vram_addr_1_next = vram_addr_new;
            end
            fetch_ahead_next = 1;
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            vram_addr_0_r                 <= 0;
            vram_addr_1_r                 <= 0;
            vram_addr_incr_0_r            <= 0;
            vram_addr_incr_1_r            <= 0;
            vram_addr_decr_0_r            <= 0;
            vram_addr_decr_1_r            <= 0;
            vram_addr_select_r            <= 0;
            vram_data0_r                  <= 0;
            vram_data1_r                  <= 0;
            sprite_bank_select_r          <= 0;
            dc_select_r                   <= 0;
            fpga_reconfigure_r            <= 0;
`ifdef VERA_AUDIO
            irq_enable_audio_fifo_low_r   <= 0;
`endif            
            irq_enable_vsync_r            <= 0;
            irq_enable_line_r             <= 0;
            irq_enable_sprite_collision_r <= 0;
            irq_status_vsync_r            <= 0;
            irq_status_line_r             <= 0;
            irq_status_sprite_collision_r <= 0;
            irq_line_r                    <= 0;
            sprites_enabled_r             <= 0;
            l0_enabled_r                  <= 0;
            l1_enabled_r                  <= 0;
            chroma_disable_r              <= 0;
            dc_hscale_r                   <= 8'd128;
            dc_vscale_r                   <= 8'd128;
            dc_border_color_r             <= 0;
            dc_active_hstart_r            <= 10'd0;
            dc_active_hstop_r             <= 10'd640;
            dc_active_vstart_r            <= 9'd0;
            dc_active_vstop_r             <= 9'd480;
            l0_color_depth_r              <= 0;
            l0_bitmap_mode_r              <= 0;
            l0_attr_mode_r                <= 0;
            l0_tile_height_r              <= 0;
            l0_tile_width_r               <= 0;
            l0_map_height_r               <= 0;
            l0_map_width_r                <= 0;
            l0_map_baseaddr_r             <= 0;
            l0_tile_baseaddr_r            <= 0;
            l0_hscroll_r                  <= 0;
            l0_vscroll_r                  <= 0;
            l1_color_depth_r              <= 0;
            l1_bitmap_mode_r              <= 0;
            l1_attr_mode_r                <= 0;
            l1_tile_height_r              <= 0;
            l1_tile_width_r               <= 0;
            l1_map_height_r               <= 0;
            l1_map_width_r                <= 0;
            l1_map_baseaddr_r             <= 0;
            l1_tile_baseaddr_r            <= 0;
            l1_hscroll_r                  <= 0;
            l1_vscroll_r                  <= 0;
            video_output_mode_r           <= 0;
`ifdef VERA_AUDIO
            audio_pcm_sample_rate_r       <= 0;
            audio_mode_stereo_r           <= 0;
            audio_mode_16bit_r            <= 0;
            audio_fifo_reset_r            <= 0;
            audio_pcm_volume_r            <= 0;
            audio_fifo_wrdata_r           <= 0;
            audio_fifo_write_r            <= 0;
`endif            
 `ifdef VERA_SPI            
            spi_select_r                  <= 0;
            spi_slow_r                    <= 0;
            spi_autotx_r                  <= 0;
`endif
            ib_addr_r                     <= 0;
            ib_wrdata_r                   <= 0;
            ib_write_r                    <= 0;

            fetch_ahead_r                 <= 0;
            fetch_ahead_port_r            <= 0;

        end else begin
            vram_addr_0_r                 <= vram_addr_0_next;
            vram_addr_1_r                 <= vram_addr_1_next;
            vram_addr_incr_0_r            <= vram_addr_incr_0_next;
            vram_addr_incr_1_r            <= vram_addr_incr_1_next;
            vram_addr_decr_0_r            <= vram_addr_decr_0_next;
            vram_addr_decr_1_r            <= vram_addr_decr_1_next;
            vram_addr_select_r            <= vram_addr_select_next;
            vram_data0_r                  <= vram_data0_next;
            vram_data1_r                  <= vram_data1_next;
            dc_select_r                   <= dc_select_next;
            sprite_bank_select_r          <= sprite_bank_select_next;
            fpga_reconfigure_r            <= fpga_reconfigure_next;
`ifdef VERA_AUDIO
            irq_enable_audio_fifo_low_r   <= irq_enable_audio_fifo_low_next;
`endif            
            irq_enable_vsync_r            <= irq_enable_vsync_next;
            irq_enable_line_r             <= irq_enable_line_next;
            irq_enable_sprite_collision_r <= irq_enable_sprite_collision_next;
            irq_status_vsync_r            <= irq_status_vsync_next;
            irq_status_line_r             <= irq_status_line_next;
            irq_status_sprite_collision_r <= irq_status_sprite_collision_next;
            irq_line_r                    <= irq_line_next;
            sprites_enabled_r             <= sprites_enabled_next;
            l0_enabled_r                  <= l0_enabled_next;
            l1_enabled_r                  <= l1_enabled_next;
            chroma_disable_r              <= chroma_disable_next;
            dc_hscale_r                   <= dc_hscale_next;
            dc_vscale_r                   <= dc_vscale_next;
            dc_border_color_r             <= dc_border_color_next;
            dc_active_hstart_r            <= dc_active_hstart_next;
            dc_active_hstop_r             <= dc_active_hstop_next;
            dc_active_vstart_r            <= dc_active_vstart_next;
            dc_active_vstop_r             <= dc_active_vstop_next;
            l0_color_depth_r              <= l0_color_depth_next;
            l0_bitmap_mode_r              <= l0_bitmap_mode_next;
            l0_attr_mode_r                <= l0_attr_mode_next;
            l0_tile_height_r              <= l0_tile_height_next;
            l0_tile_width_r               <= l0_tile_width_next;
            l0_map_height_r               <= l0_map_height_next;
            l0_map_width_r                <= l0_map_width_next;
            l0_map_baseaddr_r             <= l0_map_baseaddr_next;
            l0_tile_baseaddr_r            <= l0_tile_baseaddr_next;
            l0_hscroll_r                  <= l0_hscroll_next;
            l0_vscroll_r                  <= l0_vscroll_next;
            l1_color_depth_r              <= l1_color_depth_next;
            l1_bitmap_mode_r              <= l1_bitmap_mode_next;
            l1_attr_mode_r                <= l1_attr_mode_next;
            l1_tile_height_r              <= l1_tile_height_next;
            l1_tile_width_r               <= l1_tile_width_next;
            l1_map_height_r               <= l1_map_height_next;
            l1_map_width_r                <= l1_map_width_next;
            l1_map_baseaddr_r             <= l1_map_baseaddr_next;
            l1_tile_baseaddr_r            <= l1_tile_baseaddr_next;
            l1_hscroll_r                  <= l1_hscroll_next;
            l1_vscroll_r                  <= l1_vscroll_next;
            video_output_mode_r           <= video_output_mode_next;
`ifdef VERA_AUDIO
            audio_pcm_sample_rate_r       <= audio_pcm_sample_rate_next;
            audio_mode_stereo_r           <= audio_mode_stereo_next;
            audio_mode_16bit_r            <= audio_mode_16bit_next;
            audio_fifo_reset_r            <= audio_fifo_reset_next;
            audio_pcm_volume_r            <= audio_pcm_volume_next;
            audio_fifo_wrdata_r           <= audio_fifo_wrdata_next;
            audio_fifo_write_r            <= audio_fifo_write_next;
`endif            
 `ifdef VERA_SPI            
            spi_select_r                  <= spi_select_next;
            spi_slow_r                    <= spi_slow_next;
            spi_autotx_r                  <= spi_autotx_next;
`endif
            ib_addr_r                     <= ib_addr_next;
            ib_wrdata_r                   <= ib_wrdata_next;
            ib_write_r                    <= ib_write_next;

            fetch_ahead_r                 <= fetch_ahead_next;
            fetch_ahead_port_r            <= fetch_ahead_port_next;
        end
    end

    //////////////////////////////////////////////////////////////////////////
    // Video RAM
    //////////////////////////////////////////////////////////////////////////
    wire [14:0] l0_addr;
    wire [31:0] l0_rddata;
    wire        l0_strobe;
    wire        l0_ack;

    wire [14:0] l1_addr;
    wire [31:0] l1_rddata;
    wire        l1_strobe;
    wire        l1_ack;

    wire [14:0] spr_addr;
    wire [31:0] spr_rddata;
    wire        spr_strobe;
    wire        spr_ack;

    vram_if vram_if(
        .clk(clk),

        // Interface 0 - 8-bit (highest priority)
        .if0_addr(wb_adr[16:2]),
        .if0_wrdata(wb_dat_w),
        .if0_rddata(vram_dat_r),
        .if0_wrbytesel(wb_sel),
        .if0_strobe(wb_stb && (wb_adr >= 32'h100000) && (wb_adr < 32'h120000)),
        .if0_write(wb_we),
        .if0_ack(ib_ack),

        // Interface 1 - 32-bit read only
        .if1_addr(l0_addr),
        .if1_rddata(l0_rddata),
        .if1_strobe(l0_strobe & l0_enabled_r),
        .if1_ack(l0_ack),

        // Interface 2 - 32-bit read only
        .if2_addr(l1_addr),
        .if2_rddata(l1_rddata),
        .if2_strobe(l1_strobe & l1_enabled_r),
        .if2_ack(l1_ack),

        // Interface 3 - 32-bit read only
        .if3_addr(spr_addr),
        .if3_rddata(spr_rddata),
        .if3_strobe(spr_strobe),
        .if3_ack(spr_ack));

    //////////////////////////////////////////////////////////////////////////
    // Renderers
    //////////////////////////////////////////////////////////////////////////
    wire        next_line;

    wire  [9:0] lb_rdidx;
    wire  [7:0] l0_lb_rddata;
    wire  [7:0] l1_lb_rddata;
    wire [15:0] spr_lb_rddata;
    wire        spr_lb_erase_start;

    wire  [8:0] line_idx;
    wire        line_render_start;

    reg active_line_buf_r;
    always @(posedge clk) begin
        if (reset) begin
            active_line_buf_r <= 0;
        end else begin
            if (next_line) begin
                active_line_buf_r <= !active_line_buf_r;
            end
        end
    end

    //////////////////////////////////////////////////////////////////////////
    // Layer 0 renderer
    //////////////////////////////////////////////////////////////////////////
    wire  [9:0] l0_linebuf_wridx;
    wire  [7:0] l0_linebuf_wrdata;
    wire        l0_linebuf_wren;

    layer_renderer l0_renderer(
        .rst(reset),
        .clk(clk),

        // Composer interface
        .line_idx(line_idx),
        .line_render_start(line_render_start),

        // Register interface
        .color_depth(l0_color_depth_r),
        .bitmap_mode(l0_bitmap_mode_r),
        .attr_mode(l0_attr_mode_r),
        .tile_height(l0_tile_height_r),
        .tile_width(l0_tile_width_r),
        .map_height(l0_map_height_r),
        .map_width(l0_map_width_r),
        .map_baseaddr(l0_map_baseaddr_r),
        .tile_baseaddr(l0_tile_baseaddr_r),
        .hscroll(l0_hscroll_r),
        .vscroll(l0_vscroll_r),

        // Bus master interface
        .bus_addr(l0_addr),
        .bus_rddata(l0_rddata),
        .bus_strobe(l0_strobe),
        .bus_ack(l0_ack),

        // Line buffer interface
        .linebuf_wridx(l0_linebuf_wridx),
        .linebuf_wrdata(l0_linebuf_wrdata),
        .linebuf_wren(l0_linebuf_wren));

    // Layer 0 line buffer
    layer_line_buffer l0_line_buffer(
        .rst(reset),
        .clk(clk),

        .active_render_buffer(active_line_buf_r),

        // Renderer interface
        .renderer_wr_idx(l0_linebuf_wridx),
        .renderer_wr_data(l0_linebuf_wrdata),
        .renderer_wr_en(l0_linebuf_wren),

        // Composer interface
        .composer_rd_idx(lb_rdidx),
        .composer_rd_data(l0_lb_rddata));

    //////////////////////////////////////////////////////////////////////////
    // Layer 1 renderer
    //////////////////////////////////////////////////////////////////////////
    wire  [9:0] l1_linebuf_wridx;
    wire  [7:0] l1_linebuf_wrdata;
    wire        l1_linebuf_wren;

    layer_renderer l1_renderer(
        .rst(reset),
        .clk(clk),

        // Composer interface
        .line_idx(line_idx),
        .line_render_start(line_render_start),

        // Register interface
        .color_depth(l1_color_depth_r),
        .bitmap_mode(l1_bitmap_mode_r),
        .attr_mode(l1_attr_mode_r),
        .tile_height(l1_tile_height_r),
        .tile_width(l1_tile_width_r),
        .map_height(l1_map_height_r),
        .map_width(l1_map_width_r),
        .map_baseaddr(l1_map_baseaddr_r),
        .tile_baseaddr(l1_tile_baseaddr_r),
        .hscroll(l1_hscroll_r),
        .vscroll(l1_vscroll_r),

        // Bus master interface
        .bus_addr(l1_addr),
        .bus_rddata(l1_rddata),
        .bus_strobe(l1_strobe),
        .bus_ack(l1_ack),

        // Line buffer interface
        .linebuf_wridx(l1_linebuf_wridx),
        .linebuf_wrdata(l1_linebuf_wrdata),
        .linebuf_wren(l1_linebuf_wren));

    // Layer 1 line buffer
    layer_line_buffer l1_line_buffer(
        .rst(reset),
        .clk(clk),

        .active_render_buffer(active_line_buf_r),

        // Renderer interface
        .renderer_wr_idx(l1_linebuf_wridx),
        .renderer_wr_data(l1_linebuf_wrdata),
        .renderer_wr_en(l1_linebuf_wren),

        // Composer interface
        .composer_rd_idx(lb_rdidx),
        .composer_rd_data(l1_lb_rddata));

    //////////////////////////////////////////////////////////////////////////
    // Sprite renderer
    //////////////////////////////////////////////////////////////////////////
    wire  [7:0] sprite_idx;
    wire [31:0] sprite_attr;
    wire  [9:0] sprite_lb_renderer_rd_idx;
    wire [15:0] sprite_lb_renderer_rd_data;
    wire  [9:0] sprite_lb_renderer_wr_idx;
    wire [15:0] sprite_lb_renderer_wr_data;
    wire        sprite_lb_renderer_wr_en;

    sprite_renderer sprite_renderer(
        .rst(reset),
        .clk(clk),

        // Register interface
        .sprite_bank(sprite_bank_select_r),
        .collisions(sprite_collisions),
        .sprcol_irq(sprcol_irq),

        // Composer interface
        .line_idx(line_idx),
        .line_render_start(line_render_start),
        .frame_done(vblank_pulse),

        // Bus master interface
        .bus_addr(spr_addr),
        .bus_rddata(spr_rddata),
        .bus_strobe(spr_strobe),
        .bus_ack(spr_ack),

        // Sprite attribute RAM interface
        .sprite_idx(sprite_idx),
        .sprite_attr(sprite_attr),

        // Line buffer interface
        .linebuf_rdidx(sprite_lb_renderer_rd_idx),
        .linebuf_rddata(sprite_lb_renderer_rd_data),

        .linebuf_wridx(sprite_lb_renderer_wr_idx),
        .linebuf_wrdata(sprite_lb_renderer_wr_data),
        .linebuf_wren(sprite_lb_renderer_wr_en));

    // Sprite line buffer
    sprite_line_buffer sprite_line_buffer(
        .rst(reset),
        .clk(clk),

        .active_render_buffer(active_line_buf_r),

        // Renderer interface
        .renderer_rd_idx(sprite_lb_renderer_rd_idx),
        .renderer_rd_data(sprite_lb_renderer_rd_data),
        .renderer_wr_idx(sprite_lb_renderer_wr_idx),
        .renderer_wr_data(sprite_lb_renderer_wr_data),
        .renderer_wr_en(sprite_lb_renderer_wr_en),

        // Composer interface
        .composer_rd_idx(lb_rdidx),
        .composer_rd_data(spr_lb_rddata),
        .composer_erase_start(spr_lb_erase_start));

    initial	spr_pal_ram_wb_ack_r = 0;
	always @(posedge clk)
        if (((wb_adr >= 32'h1000) && (wb_adr < 32'h1400)) || ((wb_adr >= 32'h2000) && (wb_adr < 32'h2400)))
            spr_pal_ram_wb_ack_r  <= wb_stb;
        else
		    spr_pal_ram_wb_ack_r <= 0;

    sprite_ram sprite_attr_ram(
        .rst_i(1'b0),
        .wr_clk_i(clk),
        .rd_clk_i(clk),
        .wr_clk_en_i(1'b1),
        .rd_en_i(1'b1),
        .rd_clk_en_i(1'b1),
        .wr_en_i((wb_adr >= 32'h1000) && (wb_adr < 32'h1400) && wb_stb && wb_we),
        .wr_data_i(wb_dat_w),
        .ben_i(wb_sel),
        .wr_addr_i(wb_adr[9:2]),
        .rd_addr_i(sprite_idx),
        .rd_data_o(sprite_attr));

    //////////////////////////////////////////////////////////////////////////
    // Composer
    //////////////////////////////////////////////////////////////////////////
    wire [7:0] composer_display_data;
    wire       next_pixel;
    wire       next_frame;
    wire       composer_display_current_field;

    wire       dc_interlaced = video_output_mode_r[1];

    composer composer(
        .rst(reset),
        .clk(clk),

        // Register interface
        .interlaced(dc_interlaced),
        .frac_x_incr(dc_hscale_r),
        .frac_y_incr(dc_vscale_r),
        .border_color(dc_border_color_r),
        .active_hstart(dc_active_hstart_r),
        .active_hstop(dc_active_hstop_r),
        .active_vstart(dc_active_vstart_r),
        .active_vstop(dc_active_vstop_r),
        .irqline(irq_line_r),
        .layer0_enabled(l0_enabled_r),
        .layer1_enabled(l1_enabled_r),
        .sprites_enabled(sprites_enabled_r),

        .current_field(current_field),
        .line_irq(line_irq),
        .scanline(scanline),

        // Render interface
        .line_idx(line_idx),
        .line_render_start(line_render_start),
        .lb_rdidx(lb_rdidx),
        .layer0_lb_rddata(l0_lb_rddata),
        .layer1_lb_rddata(l1_lb_rddata),
        .sprite_lb_rddata(spr_lb_rddata),
        .sprite_lb_erase_start(spr_lb_erase_start),

        // Display interface
        .display_next_frame(next_frame),
        .display_next_line(next_line),
        .display_next_pixel(next_pixel),
        .display_current_field(composer_display_current_field),
        .display_data(composer_display_data));

    //////////////////////////////////////////////////////////////////////////
    // Palette
    //////////////////////////////////////////////////////////////////////////
    wire [15:0] palette_rgb_data;

    palette_ram palette_ram(
        .rst_i(1'b0),
        .wr_clk_i(clk),
        .rd_clk_i(clk),
        .wr_clk_en_i(1'b1),
        .rd_en_i(1'b1),
        .rd_clk_en_i(1'b1),
        .wr_en_i((wb_adr >= 32'h2000) && (wb_adr < 32'h2400) && wb_stb && wb_we),
        .wr_data_i(wb_dat_w[15:0]),
        .ben_i(wb_sel[1:0]),
        .wr_addr_i(wb_adr[9:2]),
        .rd_addr_i(composer_display_data),
        .rd_data_o(palette_rgb_data));

`ifdef VERA_COMPOSITE_VIDEO
    //////////////////////////////////////////////////////////////////////////
    // Composite video
    //////////////////////////////////////////////////////////////////////////
    wire       video_composite_next_frame;
    wire       video_composite_next_line;
    wire       video_composite_display_next_pixel;
    wire       video_composite_vblank_pulse;

    wire [5:0] video_composite_luma, video_composite_chroma;
    wire [3:0] video_rgb_r, video_rgb_g, video_rgb_b;
    wire       video_rgb_sync_n;
    wire [5:0] video_composite_chroma2 = chroma_disable_r ? 6'd0 : video_composite_chroma;

    video_composite video_composite(
        .rst(reset),
        .clk(clk),

        // Line buffer / palette interface
        .palette_rgb_data(palette_rgb_data[11:0]),

        .next_frame(video_composite_next_frame),
        .next_line(video_composite_next_line),
        .next_pixel(video_composite_display_next_pixel),
        .vblank_pulse(video_composite_vblank_pulse),
        .current_field(composer_display_current_field),

        // Composite interface
        .luma(video_composite_luma),
        .chroma(video_composite_chroma),

        // RGB interface
        .rgb_r(video_rgb_r),
        .rgb_g(video_rgb_g),
        .rgb_b(video_rgb_b),
        .rgb_sync_n(video_rgb_sync_n));
`endif /*VERA_COMPOSITE_VIDEO*/

    //////////////////////////////////////////////////////////////////////////
    // VGA video
    //////////////////////////////////////////////////////////////////////////
    wire       video_vga_next_frame;
    wire       video_vga_next_line;
    wire       video_vga_display_next_pixel;
    wire       video_vga_vblank_pulse;

    wire [3:0] video_vga_r, video_vga_g, video_vga_b;
    wire       video_vga_hsync, video_vga_vsync;

    video_vga video_vga(
        .rst(reset),
        .clk(clk),

        // Palette interface
        .palette_rgb_data(palette_rgb_data[11:0]),

        .next_frame(video_vga_next_frame),
        .next_line(video_vga_next_line),
        .next_pixel(video_vga_display_next_pixel),
        .vblank_pulse(video_vga_vblank_pulse),

        // VGA interface
        .vga_r(video_vga_r),
        .vga_g(video_vga_g),
        .vga_b(video_vga_b),
        .vga_hsync(video_vga_hsync),
        .vga_vsync(video_vga_vsync));

    //////////////////////////////////////////////////////////////////////////
    // Video output selection
    //////////////////////////////////////////////////////////////////////////
`ifdef VERA_COMPOSITE_VIDEO    
    assign next_frame   = video_output_mode_r[1] ? video_composite_next_frame         : video_vga_next_frame;
    assign next_line    = video_output_mode_r[1] ? video_composite_next_line          : video_vga_next_line;
    assign next_pixel   = video_output_mode_r[1] ? video_composite_display_next_pixel : video_vga_display_next_pixel;
    assign vblank_pulse = video_output_mode_r[1] ? video_composite_vblank_pulse       : video_vga_vblank_pulse;
`else
    assign next_frame   = video_vga_next_frame;
    assign next_line    = video_vga_next_line;
    assign next_pixel   = video_vga_display_next_pixel;
    assign vblank_pulse = video_vga_vblank_pulse;
`endif

    always @(posedge clk) case (video_output_mode_r)
        2'b01: begin
            vga_r     <= video_vga_r;
            vga_g     <= video_vga_g;
            vga_b     <= video_vga_b;
            vga_hsync <= video_vga_hsync;
            vga_vsync <= video_vga_vsync;
        end
`ifdef VERA_COMPOSITE_VIDEO    
        2'b10: begin
            vga_r     <= video_composite_luma[5:2];
            vga_g     <= {video_composite_luma[1:0], video_composite_chroma2[5:4]};
            vga_b     <= video_composite_chroma2[3:0];
            vga_hsync <= 0;
            vga_vsync <= 0;
        end

        2'b11: begin
            vga_r     <= video_rgb_r;
            vga_g     <= video_rgb_g;
            vga_b     <= video_rgb_b;
            vga_hsync <= video_rgb_sync_n;
            vga_vsync <= 0;
        end
`endif /*VERA_COMPOSITE_VIDEO*/
        default: begin
            vga_r     <= 0;
            vga_g     <= 0;
            vga_b     <= 0;
            vga_hsync <= 0;
            vga_vsync <= 0;
        end
    endcase

    //////////////////////////////////////////////////////////////////////////
    // FPGA reconfiguration
    //////////////////////////////////////////////////////////////////////////

/* `ifndef __ICARUS__
    WARMBOOT warmboot(
        .S1(1'b0),
        .S0(1'b0),
        .BOOT(fpga_reconfigure_r));
`endif
 */

 `ifdef VERA_SPI
    //////////////////////////////////////////////////////////////////////////
    // SPI interface
    //////////////////////////////////////////////////////////////////////////
    assign spi_ssel_n_sd = !spi_select_r;

    spictrl spictrl(
        .rst(reset),
        .clk(clk),

        // Register interface
        .txdata(spi_txdata),
        .txstart(spi_txstart),
        .rxdata(spi_rxdata),
        .busy(spi_busy),

        .slow(spi_slow_r),

        // SPI interface
        .spi_sck(spi_sck),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso));
`endif /*VERA_SPI*/

`ifdef VERA_AUDIO
    //////////////////////////////////////////////////////////////////////////
    // Audio
    //////////////////////////////////////////////////////////////////////////
    wire audio_write = (ib_addr_r[16:6] == 'b11111100111) && ib_do_access_r && ib_write_r;

    audio audio(
        .rst(reset),
        .clk(clk),

        // PSG interface
        .attr_addr(ib_addr_r[5:0]),
        .attr_wrdata(ib_wrdata_r),
        .attr_write(audio_write),

        // Register interface
        .sample_rate(audio_pcm_sample_rate_r),
        .mode_stereo(audio_mode_stereo_r),
        .mode_16bit(audio_mode_16bit_r),
        .volume(audio_pcm_volume_r),

        // Audio FIFO interface
        .fifo_reset(audio_fifo_reset_r),
        .fifo_wrdata(audio_fifo_wrdata_r),
        .fifo_write(audio_fifo_write_r),
        .fifo_full(audio_fifo_full),
        .fifo_almost_empty(audio_fifo_low),
        .fifo_empty(audio_fifo_empty),

        // I2S audio output
        .i2s_lrck(audio_lrck),
        .i2s_bck(audio_bck),
        .i2s_data(audio_data));
`endif /*VERA_AUDIO*/

endmodule
