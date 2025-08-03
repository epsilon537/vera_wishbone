`default_nettype none

module capture_ram (
    input  wire        clk_i,
    input  wire        clk_en_i,
    input  wire        rd_en_i,
    input  wire        wr_en_i,
    input  wire [15:0] wr_data_i,
    input  wire [ 9:0] wr_addr_i,
    input  wire [ 9:0] rd_addr_i,
    output reg  [15:0] rd_data_o
);

  reg [15:0] mem[0:639];

  always @(posedge clk_i) begin
    if (wr_en_i && clk_en_i) begin
      mem[wr_addr_i] <= wr_data_i;
    end
  end

  always @(posedge clk_i) begin
    if (rd_en_i) begin
      rd_data_o <= mem[rd_addr_i];
    end
  end

endmodule

`resetall
