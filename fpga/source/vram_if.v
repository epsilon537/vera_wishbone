//`default_nettype none

module vram_if #(
    parameter VRAM_SIZE_BYTES = (128 * 1024)  //Max. 128KB. Tested sizes are 64K and 128K.
) (
    input wire clk,

    // Interface 0 - 31-bit read-write
    input  wire [14:0] if0_addr,
    input  wire [31:0] if0_wrdata,
    output wire [31:0] if0_rddata,
    input  wire [ 3:0] if0_wrbytesel,
    input  wire        if0_strobe,
    input  wire        if0_write,
    output reg         if0_ack,

    // Interface 1 - 32-bit read only
    input  wire [14:0] if1_addr,
    output wire [31:0] if1_rddata,
    input  wire        if1_strobe,
    output reg         if1_ack,

    // Interface 2 - 32-bit read only
    input  wire [14:0] if2_addr,
    output wire [31:0] if2_rddata,
    input  wire        if2_strobe,
    output reg         if2_ack,

    // Interface 3 - 32-bit read only
    input  wire [14:0] if3_addr,
    output wire [31:0] if3_rddata,
    input  wire        if3_strobe,
    output reg         if3_ack
);

  //////////////////////////////////////////////////////////////////////////
  // Main RAM 128kB (32k x 32)
  //////////////////////////////////////////////////////////////////////////
  reg  [14:0] ram_addr_b;
  wire [31:0] ram_rddata_b;

  bytewrite_sdp_ram #(
      .NUM_COL(4),
      .COL_WIDTH(8),
      .ADDR_WIDTH($clog2(VRAM_SIZE_BYTES / 4))
  ) bytewrite_sdp_ram_inst (
      .clk  (clk),
      .enaA (1'b1),
      .weA  ((if0_strobe & if0_write) ? if0_wrbytesel : 4'b0),
      .addrA(if0_addr),
      .dinA (if0_wrdata),
      .doutA(if0_rddata),

      .enaB (1'b1),
      .addrB(ram_addr_b),
      .doutB(ram_rddata_b)
  );

  //////////////////////////////////////////////////////////////////////////
  // Time slotted memory access for ifs 1-3: Three time slots, one clock
  // period each, each slot assigned to one port.
  // if0 has its own port to the ram so doesn't require a timeslot.
  //////////////////////////////////////////////////////////////////////////
  reg if0_ack_next;
  reg if1_ack_next;
  reg if2_ack_next;
  reg if3_ack_next;

  reg [1:0] selector_reg, selector_next;

  initial selector_reg = 2'h0;

  always @* begin
    if (selector_reg < 2'd2) begin
      //Max. selector next value is 2.
      selector_next = selector_reg + 1;
    end else begin
      selector_next = 2'd0;
    end

    ram_addr_b   = 15'b0;
    if0_ack_next = 1'b0;
    if1_ack_next = 1'b0;
    if2_ack_next = 1'b0;
    if3_ack_next = 1'b0;

    if (if0_strobe) begin
      if0_ack_next = 1'b1;
    end

    case (selector_reg)
      2'h0:
      if (if1_strobe) begin
        ram_addr_b   = if1_addr;
        if1_ack_next = 1'b1;
      end
      2'h1:
      if (if2_strobe) begin
        ram_addr_b   = if2_addr;
        if2_ack_next = 1'b1;
      end
      2'h2:
      if (if3_strobe) begin
        ram_addr_b   = if3_addr;
        if3_ack_next = 1'b1;
      end
      2'h3: ;  //Should never happen
    endcase
  end

  always @(posedge clk) begin
    selector_reg <= selector_next;
    if0_ack <= if0_ack_next;
    if1_ack <= if1_ack_next;
    if2_ack <= if2_ack_next;
    if3_ack <= if3_ack_next;
  end

  assign if1_rddata = ram_rddata_b;
  assign if2_rddata = ram_rddata_b;
  assign if3_rddata = ram_rddata_b;

endmodule
