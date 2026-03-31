`timescale 1ns / 1ps
module apb_slave_fnd(
    input               PCLK,
    input               PRESET,
    input [31:0]        PADDR,
    input [31:0]        PWDATA,
    input               PWRITE,
    input               PENABLE,
    input               PSEL,
    output logic        PREADY,
    output [31:0]       PRDATA,
    output [15:0] 		fnd_in_data
);
	
	// Address
	localparam [11:0] FND_O_ADDR = 12'h000;
	
	// Register
	logic [13:0] fnd_o_reg;

	always_ff @(posedge PCLK, posedge PRESET) begin
		if (PRESET) fnd_o_reg <= 0;
		else begin
			if (PSEL && PENABLE && PWRITE && (PADDR[11:0] == FND_O_ADDR)) begin
				fnd_o_reg <= PWDATA[13:0];
			end
		end
	end	

	assign PRDATA = (PADDR[11:0] == FND_O_ADDR)? {17'b0, fnd_o_reg} : 32'b0;

	assign PREADY = PSEL & PENABLE;

	assign fnd_in_data = { 2'b00, fnd_o_reg };

endmodule
