`timescale 1ns / 1ps

module rv32i_mcu(
	input clk,
	input rst,

	input [7:0]  	gpi,
	output [7:0]  	gpo,
	inout [15:0] 	gpio,

	output [3:0] 	fnd_digit,
	output [7:0]	fnd_data,
	
	input 			rx,
	output 			tx
);

	logic [31:0] w_instr_addr, w_instr_data;
	logic w_bus_ready, w_bus_wreq, w_bus_rreq;
	logic [2:0] w_mem_width;
	logic [31:0] w_data_addr, w_data_wdata, w_data_rdata;

	// BUS Wire
	logic [31:0] paddr;
	logic [31:0] pwdata;
	logic [31:0] prdata [0:5];
	logic 		 pready [0:5];
	logic 		 pslverr [0:5];
	logic [5:0]	 psel;
	logic 		 penable;

	instruction_memory U_INST_MEM (
		.instr_addr(w_instr_addr),
		.instr_data(w_instr_data)
	);

	rv32i_cpu U_CPU (
		.clk(clk),
		.rst(rst),
		.instr_data(w_instr_data),
		.bus_rdata(w_data_rdata),
		.bus_ready(w_bus_ready),
		.instr_addr(w_instr_addr),
		.rreq(w_bus_rreq),
		.wreq(w_bus_wreq),
		.bus_addr(w_data_addr),
		.bus_wdata(w_data_wdata),
		.d_mem_width(w_mem_width)
	);

	apb_master U_APB_BUS_master(
        .PCLK       (clk),
        .PRESET     (rst),
        .Addr       (w_data_addr),
        .Wdata      (w_data_wdata),
        .WREQ       (w_bus_wreq),
        .RREQ       (w_bus_rreq),
        .SlvERR     (slverr),
        .Rdata      (w_data_rdata),
        .Ready      (w_bus_ready),
        .PADDR      (paddr),
        .PWDATA     (pwdata),
        .PSEL       (psel),
        .PENABLE    (penable),
        .PWRITE     (pwrite),

        .PSlvERR0   (pslverr[0]),
        .PRDATA0    (prdata[0]),
        .PREADY0    (pready[0]),

        .PSlvERR1   (pslverr[1]),
        .PRDATA1    (prdata[1]),
        .PREADY1    (pready[1]),

        .PSlvERR2   (pslverr[2]),
        .PRDATA2    (prdata[2]),
        .PREADY2    (pready[2]),

        .PSlvERR3   (pslverr[3]),
        .PRDATA3    (prdata[3]),
        .PREADY3    (pready[3]),

        .PSlvERR4   (pslverr[4]),
        .PRDATA4    (prdata[4]),
        .PREADY4    (pready[4]),

        .PSlvERR5   (pslverr[5]),
        .PRDATA5    (prdata[5]),
        .PREADY5    (pready[5])
    );

	// RAM
	wire			apbif2ram_we;
	wire [31:0] 	apbif2ram_addr, apbif2ram_wdata, apbif2ram_rdata;
	apb_slave_ram U_APB_INTERF_RAM (
    	.PCLK		(clk),
    	.PRESET		(rst),
    	.PADDR		(paddr),
    	.PWDATA		(pwdata),
    	.PWRITE		(pwrite),
    	.PENABLE	(penable),
    	.PSEL		(psel[0]),
    	.PRDATA		(prdata[0]),
    	.PREADY		(pready[0]),

    	.we			(apbif2ram_we),
    	.addr		(apbif2ram_addr),
    	.wdata		(apbif2ram_wdata),
    	.rdata		(apbif2ram_rdata)
	);
	ram U_RAM (
    	.clk		(clk),
    	.we			(apbif2ram_we),
    	.addr		(apbif2ram_addr),
    	.wdata		(apbif2ram_wdata),
    	.rdata		(apbif2ram_rdata)
	);

	// GPO
	apb_slave_gpo U_APB_GPO (
    	.PCLK		(clk),
    	.PRESET		(rst),
    	.PADDR		(paddr),
    	.PWDATA		(pwdata),
    	.PWRITE		(pwrite),
    	.PENABLE	(penable),
    	.PSEL		(psel[1]),
		.PRDATA		(prdata[1]),
    	.PREADY		(pready[1]),
    	.gpo_out	(gpo)
	);

	// GPI
	apb_slave_gpi U_APB_GPI (
	    .PCLK		(clk),
	    .PRESET		(rst),
	    .PADDR		(paddr),
	    .PWDATA		(pwdata),
	    .PWRITE		(pwrite),
	    .PENABLE	(penable),
	    .PSEL		(psel[2]),
	    .PRDATA		(prdata[2]),
	    .PREADY		(pready[2]),
	    .gpi_in		(gpi)
	);

	// GPIO
	apb_slave_gpio U_APB_GPIO (
	    .PCLK		(clk),
	    .PRESET		(rst),
	    .PADDR		(paddr),
	    .PWDATA		(pwdata),
	    .PWRITE		(pwrite),
	    .PENABLE	(penable),
	    .PSEL		(psel[3]),
	    .PRDATA		(prdata[3]),
	    .PREADY		(pready[3]),
		.gpio		(gpio)
	);

	// FND
	wire [15:0] fnd_in_data;
	apb_slave_fnd U_APB_FND (
		.PCLK		(clk),
		.PRESET		(rst),
		.PADDR		(paddr),
		.PWDATA		(pwdata),
		.PWRITE		(pwrite),
		.PENABLE	(penable),
		.PSEL		(psel[4]),
		.PRDATA		(prdata[4]),
		.PREADY		(pready[4]),
		.fnd_in_data(fnd_in_data)
	);
	fnd_controller U_FND_CTRL(
	    .clk		(clk),
	    .reset		(rst),
		.fnd_in_data(fnd_in_data),
	    .fnd_digit	(fnd_digit),
	    .fnd_data	(fnd_data)
	);

	// UART
	wire tx_start, rx_done, rxfifo_empty, rx_get, tx_busy, b_tick;
	wire [1:0] baud_rate;
	wire [7:0] rx_data, fifo_rx_reg, tx_data;
	apb_slave_uart U_APB_UART (
    	.PCLK		(clk),
    	.PRESET		(rst),
    	.PADDR		(paddr),
    	.PWDATA		(pwdata),
    	.PWRITE		(pwrite),
    	.PENABLE	(penable),
    	.PSEL		(psel[5]),
    	.PREADY		(pready[5]),
    	.PRDATA		(prdata[5]),
    	.i_rx_data	(fifo_rx_reg),
    	.i_rx_done	(~rxfifo_empty),
		.o_rx_get	(rx_get),
    	.o_tx_start	(tx_start),
    	.o_tx_data	(tx_data),
    	.i_tx_busy	(tx_busy),
		.o_baud_rate(baud_rate)
	);
	baud_tick_sampling_divide_3types U_BAUD_TICK_GEN (
	    .clk			(clk),
	    .rst			(rst),
		.i_baud_rate 	(baud_rate),
	    .b_tick			(b_tick)
	);
	uart_rx U_UART_RX (
	    .clk		(clk),
	    .rst		(rst),
	    .rx			(rx),
	    .b_tick		(b_tick),
	    .rx_data	(rx_data),
	    .rx_done	(rx_done)
	);
	fifo #(
	    .DEPTH		(8),
	    .BIT_WIDTH 	(8)
	) U_RX_FIFO (
	    .clk		(clk),
	    .rst		(rst),
	    .push		(rx_done),
	    .pop		(rx_get),
	    .push_data	(rx_data),
	    .pop_data	(fifo_rx_reg),
	    .full		(),
	    .empty		(rxfifo_empty)
	);
	uart_tx U_UART_TX (
	    .clk		(clk),
	    .rst		(rst),
	    .tx_start	(tx_start),
	    .b_tick		(b_tick),  // *16
	    .tx_data	(tx_data),
	    .tx_busy	(tx_busy),
	    .tx_done	(),
	    .uart_tx	(tx)
	);

endmodule

