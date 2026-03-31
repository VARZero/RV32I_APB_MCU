`timescale 1ns / 1ps
module apb_slave_uart(
    input               PCLK,
    input               PRESET,
    input [31:0]        PADDR,
    input [31:0]        PWDATA,
    input               PWRITE,
    input               PENABLE,
    input               PSEL,
    output logic        PREADY,
    output logic [31:0] PRDATA,

    input [7:0]         i_rx_data,
    input               i_rx_done,
    output logic        o_rx_get,
    
    output              o_tx_start,
    output [7:0]        o_tx_data,
    input               i_tx_busy,
    output [1:0]        o_baud_rate
);
    // Address Define
    localparam [11:0] UART_CTL_ADDR = 12'h000;
    localparam [11:0] UART_BAUD_ADDR = 12'h004;
    localparam [11:0] UART_STATUS_ADDR = 12'h008;
    localparam [11:0] UART_TX_DATA_ADDR = 12'h00C;
    localparam [11:0] UART_RX_DATA_ADDR = 12'h010;
    
    // Registers Variables
    logic [31:0] uart_ctl_reg;
    logic [31:0] uart_baud_reg;
    logic [31:0] uart_status_reg;
    logic [31:0] uart_tx_data_reg;
    logic [31:0] uart_rx_data_reg;

    // Registers Modeling
    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            uart_ctl_reg     <= 0;
            uart_baud_reg    <= 0;
            uart_status_reg  <= 0;
            uart_tx_data_reg <= 0;
            uart_rx_data_reg <= 0;
        end
        else begin
            uart_status_reg <= { i_rx_done, 30'b0, i_tx_busy };
            uart_rx_data_reg <= { 24'b0, i_rx_data };
            if (PSEL && PENABLE && PWRITE) begin
                case(PADDR[11:0])
                    UART_CTL_ADDR     : uart_ctl_reg     <= PWDATA;
                    UART_BAUD_ADDR    : uart_baud_reg    <= PWDATA;
                    UART_TX_DATA_ADDR : uart_tx_data_reg <= PWDATA;
                endcase
            end
        end
    end

	// CL Modeling (APB READ, APB READY, and INPUTs/OUTPUTs)
	always_comb begin
		PRDATA = 0; o_rx_get = 0;
		if (PSEL && PENABLE) begin
			case(PADDR[11:0])
				UART_CTL_ADDR	    : PRDATA = uart_ctl_reg;
                UART_BAUD_ADDR  	: PRDATA = uart_baud_reg; 
                UART_STATUS_ADDR  	: PRDATA = uart_status_reg;
                UART_TX_DATA_ADDR  	: PRDATA = uart_tx_data_reg;
                UART_RX_DATA_ADDR  	: begin PRDATA = uart_rx_data_reg; o_rx_get = 1; end 
			endcase
		end
	end
    
	assign PREADY = PSEL & PENABLE;

    assign o_tx_start = uart_ctl_reg[0];
    assign o_tx_data  = uart_tx_data_reg[7:0];
    assign o_baud_rate = uart_baud_reg[1:0];

endmodule
