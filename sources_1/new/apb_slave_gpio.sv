`timescale 1ns / 1ps
module apb_slave_gpio(
    input               PCLK,
    input               PRESET,
    input [31:0]        PADDR,
    input [31:0]        PWDATA,
    input               PWRITE,
    input               PENABLE,
    input               PSEL,
    output logic        PREADY,
    output logic [31:0] PRDATA,

	inout [15:0]		gpio
);
	// Address Define
	localparam [11:0] GPIO_CTL_ADDR = 12'h000;
	localparam [11:0] GPIO_O_ADDR 	= 12'h004;
	localparam [11:0] GPIO_I_ADDR 	= 12'h008;

	// Registers Variable
	logic [15:0] gpio_ctl_reg;
	logic [15:0] gpio_o_reg;
	//logic [15:0] gpio_i_reg, gpio_i_next;

	// SL Modeling (Including APB WRITE)
	always_ff @(posedge PCLK, posedge PRESET) begin
		if (PRESET) begin
			gpio_ctl_reg	<= 0;
			gpio_o_reg		<= 0;
			//gpio_i_reg		<= 0;
		end
		else begin
			// gpio_i_reg 	<= gpio_i_next;
			if (PSEL && PENABLE && PWRITE) begin
				case(PADDR[11:0])
					GPIO_CTL_ADDR: gpio_ctl_reg <= PWDATA[15:0];
					GPIO_O_ADDR	 : gpio_o_reg 	<= PWDATA[15:0];
				endcase
			end
		end
	end

	// CL Modeling (APB READ, APB READY, and INPUTs/OUTPUTs)
	always_comb begin
		PRDATA = 0;
		if (PSEL && PENABLE) begin
			case(PADDR[11:0])
				GPIO_CTL_ADDR	: PRDATA = gpio_ctl_reg;
                GPIO_O_ADDR  	: PRDATA = gpio_o_reg; 
                GPIO_I_ADDR  	: PRDATA = gpio/*gpio_i_reg*/;
			endcase
		end
	end

	assign PREADY = PSEL & PENABLE;
	
	genvar bit_sel;
	generate
		for(bit_sel = 0; bit_sel < 16; bit_sel++) begin
			//assign gpio_i_next[bit_sel] = (~gpio_ctl_reg[bit_sel])? gpio[bit_sel] : 1'bz;
			assign gpio[bit_sel] = (gpio_ctl_reg[bit_sel])? gpio_o_reg[bit_sel] : 1'bz;
		end
	endgenerate

endmodule

