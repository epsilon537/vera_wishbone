//`default_nettype none

module vera_top #(
  parameter VRAM_SIZE_BYTES=(128*1024) //Max. 128KB. Tested sizes are 64K and 128K.
  )
    (
    input  wire       clk,
    input  wire       reset,

    //32-bit pipelined Wishbone interface.
    input wire [16:0]  wb_adr,
    input wire [31:0]  wb_dat_w,
    output wire [31:0] wb_dat_r,
    input wire [3:0]   wb_sel,
    output wire        wb_stall,
    input wire         wb_cyc,
    input wire         wb_stb,
    output wire        wb_ack,
    input wire         wb_we,
    output wire        wb_err,

    // IRQ
    output wire        irq_n,

    // VGA interface
    output reg  [3:0]  vga_r       /* synthesis syn_useioff = 1 */,
    output reg  [3:0]  vga_g       /* synthesis syn_useioff = 1 */,
    output reg  [3:0]  vga_b       /* synthesis syn_useioff = 1 */,
    output reg         vga_hsync   /* synthesis syn_useioff = 1 */,
    output reg         vga_vsync   /* synthesis syn_useioff = 1 */

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
    wire [15:0] capture_ram_dat_r;
    wire [31:0] vram_dat_r;
    wire       capture_complete_stb;

    reg        sprite_bank_select_r,          sprite_bank_select_next;
    reg        capture_en_r,                  capture_en_next;
    reg        irq_enable_vsync_r,            irq_enable_vsync_next;
    reg        irq_enable_line_r,             irq_enable_line_next;
    reg        irq_enable_sprite_collision_r, irq_enable_sprite_collision_next;
`ifdef VERA_AUDIO
    reg        irq_enable_audio_fifo_low_r,   irq_enable_audio_fifo_low_next;
`endif
    reg        irq_status_vsync_r,            irq_status_vsync_next;
    reg        irq_status_line_r,             irq_status_line_next;
    reg        irq_status_sprite_collision_r, irq_status_sprite_collision_next;
    reg  [9:0] irq_line_r,                    irq_line_next;
    reg        sprites_enabled_r,             sprites_enabled_next;
    reg        l0_enabled_r,                  l0_enabled_next;
    reg        l1_enabled_r,                  l1_enabled_next;

`ifdef VERA_COMPOSITE_VIDEO
    reg        chroma_disable_r,              chroma_disable_next;
`endif
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

`ifdef VERA_AUDIO
    wire       audio_fifo_low;
    wire       audio_fifo_empty;
`endif
    wire       sprcol_irq;
    wire       vblank_pulse;
    wire       line_irq;
    wire [9:0] scanline;

    /*Register read interface*/
    reg [31:0] reg_rddata;
    always @* begin
        reg_rddata = 32'h0;

        if (wb_stb && !wb_we) begin
            case (wb_adr[5:0])
                6'h00: reg_rddata = {30'b0, capture_en_r, sprite_bank_select_r};

                6'h01: reg_rddata = {24'b0, dc_border_color_r};

                6'h02: reg_rddata = {28'b0,
`ifdef VERA_AUDIO
                                irq_enable_audio_fifo_low_r,
`else
                                1'b0,
`endif
                                irq_enable_sprite_collision_r, irq_enable_line_r, irq_enable_vsync_r};
                6'h03: reg_rddata = {24'b0, sprite_collisions,
`ifdef VERA_AUDIO
                                audio_fifo_low,
`else
                                1'b0,
`endif
                                irq_status_sprite_collision_r, irq_status_line_r, irq_status_vsync_r};
                6'h04: reg_rddata = {22'b0, irq_line_r};
                6'h05: reg_rddata = {22'b0,   scanline};
                6'h06: reg_rddata = {25'b0, sprites_enabled_r, l1_enabled_r, l0_enabled_r, 2'b0, video_output_mode_r};

                6'h08: reg_rddata = {24'b0,dc_hscale_r};
                6'h09: reg_rddata = {24'b0, dc_vscale_r};
                6'h0a: reg_rddata = {22'b0, dc_active_hstart_r};
                6'h0b: reg_rddata = {22'b0, dc_active_hstop_r};
                6'h0c: reg_rddata = {23'b0, dc_active_vstart_r};
                6'h0d: reg_rddata = {23'b0, dc_active_vstop_r};
                6'h10: reg_rddata = {24'b0, l0_map_height_r, l0_map_width_r, l0_attr_mode_r, l0_bitmap_mode_r, l0_color_depth_r};
                6'h11: reg_rddata = {24'b0, l0_map_baseaddr_r};
                6'h12: reg_rddata = {24'b0, l0_tile_baseaddr_r[7:2], l0_tile_height_r, l0_tile_width_r};
                6'h14: reg_rddata = {20'b0, l0_hscroll_r};
                6'h15: reg_rddata = {20'b0, l0_vscroll_r};
                6'h20: reg_rddata = {24'b0, l1_map_height_r, l1_map_width_r, l1_attr_mode_r, l1_bitmap_mode_r, l1_color_depth_r};
                6'h21: reg_rddata = {24'b0, l1_map_baseaddr_r};
                6'h22: reg_rddata = {24'b0, l1_tile_baseaddr_r[7:2], l1_tile_height_r, l1_tile_width_r};
                6'h24: reg_rddata = {20'b0, l1_hscroll_r};
                6'h25: reg_rddata = {20'b0, l1_vscroll_r};

`ifdef VERA_AUDIO
                5'h1B: reg_rddata = {audio_fifo_full, audio_fifo_empty, audio_mode_16bit_r, audio_mode_stereo_r, audio_pcm_volume_r};
                5'h1C: reg_rddata = audio_pcm_sample_rate_r;
                5'h1D: reg_rddata = 8'h00;
`endif
                default: reg_rddata = 32'h00;
            endcase
        end
    end

    //Only registers, capture RAM and VRAM are readable. Palette and Sprite RAM are not.
    assign wb_dat_r = (wb_adr < 17'h1000>>2) ? reg_rddata :
      (wb_adr < 17'h4000>>2) ? {16'b0, capture_ram_dat_r} : vram_dat_r;

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

    /*Wishbone interfacing*/
    reg [5:0] wraddr_r;
    reg [31:0] wrdata_r;
    reg do_reg_read, do_reg_write, do_capture_read_r;
    reg spr_pal_ram_wb_ack_r;
    wire vram_ack;
    wire do_capture_read;

    always @(posedge clk) begin
        do_reg_read <= 1'b0;
        do_reg_write <= 1'b0;
        do_capture_read_r <= do_capture_read;
        //register write
        if (!do_reg_write && wb_stb && wb_we && (wb_adr < 17'h1000>>2)) begin
            wrdata_r <= wb_dat_w;
            wraddr_r <= wb_adr[5:0];
            do_reg_write <= 1'b1;
        end

        //register read
        if (!do_reg_read && wb_stb && !wb_we && (wb_adr < 17'h1000>>2)) begin
            do_reg_read <= 1'b1;
        end

    end

    assign do_capture_read = wb_stb && !wb_we && (wb_adr >= 17'h3000>>2) && (wb_adr < 17'h3a00>>2);
    assign wb_ack = (do_capture_read_r | do_reg_read |
      do_reg_write | vram_ack | spr_pal_ram_wb_ack_r) & wb_cyc;
    assign wb_err = 1'b0;
    assign wb_stall = !wb_cyc ? 1'b0 : !wb_ack;

    always @* begin
        sprite_bank_select_next          = sprite_bank_select_r;
        capture_en_next                  = capture_en_r;
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
`ifdef VERA_COMPOSITE_VIDEO
        chroma_disable_next              = chroma_disable_r;
`endif
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

        if (capture_complete_stb)
          capture_en_next = 0;

        if (do_reg_write) begin
            case (wraddr_r[5:0])
                6'h00: begin
                    sprite_bank_select_next = wrdata_r[0];
                    capture_en_next = wrdata_r[1];
                end
                6'h01: dc_border_color_next    = wrdata_r[7:0];
                6'h02: begin
`ifdef VERA_AUDIO
                    irq_enable_audio_fifo_low_next   = wrdata_r[3];
`endif
                    irq_enable_sprite_collision_next = wrdata_r[2];
                    irq_enable_line_next             = wrdata_r[1];
                    irq_enable_vsync_next            = wrdata_r[0];
                end
                6'h03: begin
                    // Clear status bits
                    irq_status_sprite_collision_next = irq_status_sprite_collision_r & !wrdata_r[2];
                    irq_status_line_next             = irq_status_line_r             & !wrdata_r[1];
                    irq_status_vsync_next            = irq_status_vsync_r            & !wrdata_r[0];
                end
                6'h04: irq_line_next                 = wrdata_r[9:0];
                6'h06: begin
                    sprites_enabled_next   = wrdata_r[6];
                    l1_enabled_next        = wrdata_r[5];
                    l0_enabled_next        = wrdata_r[4];
                    video_output_mode_next = wrdata_r[1:0];
                end
                6'h08: dc_hscale_next        = wrdata_r[7:0];
                6'h09: dc_vscale_next        = wrdata_r[7:0];
                6'h0a: dc_active_hstart_next = wrdata_r[9:0];
                6'h0B: dc_active_hstop_next  = wrdata_r[9:0];
                6'h0C: dc_active_vstart_next = wrdata_r[8:0];
                6'h0D: dc_active_vstop_next  = wrdata_r[8:0];
                6'h10: begin
                    l0_map_height_next  = wrdata_r[7:6];
                    l0_map_width_next   = wrdata_r[5:4];
                    l0_attr_mode_next   = wrdata_r[3];
                    l0_bitmap_mode_next = wrdata_r[2];
                    l0_color_depth_next = wrdata_r[1:0];
                end
                6'h11: l0_map_baseaddr_next = wrdata_r[7:0];
                6'h12: begin
                    l0_tile_baseaddr_next[7:2] = wrdata_r[7:2];
                    l0_tile_baseaddr_next[1:0] = 0;

                    l0_tile_height_next = wrdata_r[1];
                    l0_tile_width_next  = wrdata_r[0];
                end
                6'h14: l0_hscroll_next = wrdata_r[11:0];
                6'h15: l0_vscroll_next = wrdata_r[11:0];
                6'h20: begin
                    l1_map_height_next  = wrdata_r[7:6];
                    l1_map_width_next   = wrdata_r[5:4];
                    l1_attr_mode_next   = wrdata_r[3];
                    l1_bitmap_mode_next = wrdata_r[2];
                    l1_color_depth_next = wrdata_r[1:0];
                end
                6'h21: l1_map_baseaddr_next = wrdata_r[7:0];
                6'h22: begin
                    l1_tile_baseaddr_next[7:2] = wrdata_r[7:2];
                    l1_tile_baseaddr_next[1:0] = 0;

                    l1_tile_height_next = wrdata_r[1];
                    l1_tile_width_next  = wrdata_r[0];
                end
                6'h24: l1_hscroll_next = wrdata_r[11:0];
                6'h25: l1_vscroll_next = wrdata_r[11:0];

`ifdef VERA_AUDIO
                5'h1B: begin
                    audio_fifo_reset_next       = wrdata_r[7];
                    audio_mode_16bit_next       = wrdata_r[5];
                    audio_mode_stereo_next      = wrdata_r[4];
                    audio_pcm_volume_next       = wrdata_r[3:0];
                end
                5'h1C: audio_pcm_sample_rate_next = wrdata_r;
                5'h1D: begin
                    audio_fifo_wrdata_next = wrdata_r;
                    audio_fifo_write_next  = 1;
                end
`endif
                default: begin
                end
            endcase
        end

        if (sprcol_irq) begin
            irq_status_sprite_collision_next = 1;
        end
        if (line_irq) begin
            irq_status_line_next = 1;
        end
        if (vblank_pulse) begin
            irq_status_vsync_next = 1;
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            sprite_bank_select_r          <= 0;
            capture_en_r                  <= 0;
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
`ifdef VERA_COMPOSITE_VIDEO
            chroma_disable_r              <= 0;
`endif
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
        end else begin
            sprite_bank_select_r          <= sprite_bank_select_next;
            capture_en_r                  <= capture_en_next;
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
`ifdef VERA_COMPOSITE_VIDEO
            chroma_disable_r              <= chroma_disable_next;
`endif
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

    localparam VRAM_START_WORD_ADDR = 17'h10000; //Byte address = 0x4000.

    vram_if #(VRAM_SIZE_BYTES) vram_if(
        .clk(clk),

        // Interface 0 - 32-bit read-write
        .if0_addr(wb_adr[14:0]),
        .if0_wrdata(wb_dat_w),
        .if0_rddata(vram_dat_r),
        .if0_wrbytesel(wb_sel),
        .if0_strobe(wb_stb && (wb_adr >= VRAM_START_WORD_ADDR)),
        .if0_write(wb_we),
        .if0_ack(vram_ack),

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
`ifdef SYS_CLK_25MHZ
    reg clk_en=1;
`else
    reg clk_en=1;
`endif
    //This piece of sequential logic needs to run at pixel clock rate, i.e. 1/2 the master clock rate.
    //Hence the clk_en.
    always @(posedge clk) begin
        if (reset) begin
            active_line_buf_r <= 0;
`ifdef SYS_CLK_25MHZ
            clk_en <= 1;
`else
            clk_en <= 1;
`endif
        end else begin
`ifndef SYS_CLK_25MHZ
            clk_en <= ~clk_en;
`endif
            if (next_line && clk_en) begin
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

    localparam SPRITE_RAM_START  = 17'h1000;
    localparam SPRITE_RAM_END    = 17'h1400;
    localparam PALETTE_RAM_START = 17'h2000;
    localparam PALETTE_RAM_END   = 17'h2400;

    //For sprite and palette RAM, ack the transaction 1 cycle after receiving the strobe.
    initial  spr_pal_ram_wb_ack_r = 0;
  always @(posedge clk)
        if (((wb_adr >= SPRITE_RAM_START>>2) && (wb_adr < SPRITE_RAM_END>>2)) || ((wb_adr >= PALETTE_RAM_START>>2) && (wb_adr <PALETTE_RAM_END>>2)))
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
        .wr_en_i((wb_adr >= SPRITE_RAM_START>>2) && (wb_adr < SPRITE_RAM_END>>2) && wb_stb && wb_we),
        .wr_data_i(wb_dat_w),
        .ben_i(wb_sel),
        .wr_addr_i(wb_adr[7:0]),
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

        .current_field(),
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
        .wr_en_i((wb_adr >= PALETTE_RAM_START>>2) && (wb_adr < PALETTE_RAM_END>>2) && wb_stb && wb_we),
        .wr_data_i(wb_dat_w[15:0]),
        .ben_i(wb_sel[1:0]),
        .wr_addr_i(wb_adr[7:0]),
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
`else
    assign composer_display_current_field = 1'b0;
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

        // The capture interface
        .capture_en_i(capture_en_r),
        .capture_line_i(irq_line_r),
        .capture_rd_en_i(do_capture_read),
        .capture_rd_addr_i(wb_adr[9:0]),
        .capture_rd_data_o(capture_ram_dat_r),
        .capture_complete_stb_o(capture_complete_stb),

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
