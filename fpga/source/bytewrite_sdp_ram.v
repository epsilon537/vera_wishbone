//Byte write enable simple dual port ram.
module bytewrite_sdp_ram
#(
  parameter NUM_COL = 4,
  parameter COL_WIDTH = 8,
  parameter ADDR_WIDTH = 10,
  // Addr Width in bits : 2 *ADDR_WIDTH = RAM Depth
  parameter DATA_WIDTH = NUM_COL*COL_WIDTH // Data Width in bits
) (
  input wire clk,
  input wire enaA,
  input wire [NUM_COL-1:0] weA,
  input wire [ADDR_WIDTH-1:0] addrA,
  input wire [DATA_WIDTH-1:0] dinA,
  output reg [DATA_WIDTH-1:0] doutA,

  input wire enaB,
  input wire [ADDR_WIDTH-1:0] addrB,
  output reg [DATA_WIDTH-1:0] doutB
);

// Core Memory
reg [DATA_WIDTH-1:0] ram_block [(2**ADDR_WIDTH)-1:0];

integer i;
// Port-A Operation
always @ (posedge clk) begin
  if(enaA) begin
    for(i=0;i<NUM_COL;i=i+1) begin
      if(weA[i]) begin
        ram_block[addrA][i*COL_WIDTH +: COL_WIDTH] <= dinA[i*COL_WIDTH +: COL_WIDTH];
      end
    end
    doutA <= ram_block[addrA];
  end
end

// Port-B Operation:
always @ (posedge clk) begin
  if(enaB) begin
    doutB <= ram_block[addrB];
  end
end

endmodule

