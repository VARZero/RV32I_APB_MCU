`timescale 1ns / 1ps
`include "define.vh"

module rv32i_datapath (
    input clk,
    input rst,
    input [31:0] instr_data,
	input [31:0] dr_data,
    output [31:0] instr_addr,
	output [31:0] d_addr,
	output [31:0] dw_data,
	output [2:0]  d_width,
	
	output			o_btaken,
	input [3:0]		i_state_family,
	input 			i_ctrl_inalusel, // use PC MUX
	input [1:0] 	i_ctrl_nextpcsel,
	input 			i_ctrl_pcupdate,
	input [3:0] 	i_ctrl_aluctrl,
	input 			i_ctrl_dwe,
	input [2:0]		i_ctrl_rfsrcsel,
	input 			i_ctrl_rfwe
);
	
	// Instruction Split
	wire [4:0] inst_rd, inst_rs1, inst_rs2;
	wire [2:0] inst_funct3;
	assign inst_rd = instr_data[11:7];
	assign inst_rs1 = instr_data[19:15];
	assign inst_rs2 = instr_data[24:20];
	assign inst_funct3 = instr_data[14:12];
	wire [31:0] inst_imm;
	assign inst_imm = instr_data;
	
	// For RF <-> WB
	wire [31:0] rfsrc;

	// FETCH Stage
	wire [7:0] fetch_reg_out;
	wire [4:0] fetch_rd;
	wire [2:0] fetch_funct3;
	stage_register #(.WIDHT(8)) U_FETCH_STAGE_REG (
		.clk(clk),
		.rst(rst),
		.en(i_state_family[0]),
		.data_in({inst_funct3, inst_rd}),
		.data_out(fetch_reg_out)
	);
	assign fetch_rd = fetch_reg_out[4:0];
	assign fetch_funct3 = fetch_reg_out[7:5];
	assign d_width = fetch_funct3;

	// DECODE Stage
	wire [31:0] rf_rd1, rf_rd2;
	register_file U_RF (
		.clk	(clk),
		.rst	(rst),
		.RA1	(inst_rs1),
		.RA2	(inst_rs2),
		.WA		(fetch_rd),
		.Wdata	(rfsrc),
		.rf_we	(i_ctrl_rfwe),
		.RD1	(rf_rd1),
		.RD2	(rf_rd2)
	);
	wire [31:0] immext_imm;
	imm_extender U_IMM_EXT (
		.instr_code	(inst_imm),
		.data_out	(immext_imm)
	);
	wire [95:0] decode_reg_out;
	wire [31:0] decode_rd1, decode_rd2;
	wire [31:0] decode_imm;
	stage_register #(.WIDHT(96)) U_DECODE_STAGE_REG (
		.clk(clk),
		.rst(rst),
		.en(i_state_family[1]),
		.data_in({immext_imm, rf_rd2, rf_rd1}),
		.data_out(decode_reg_out)
	);
	assign decode_rd1 = decode_reg_out[31:0];
	assign decode_rd2 = decode_reg_out[63:32];
	assign decode_imm = decode_reg_out[95:64];

	// EXECUTE Stage
	wire [31:0] alusrc;
	mux_32bit U_BCHAN_ALU_MUX (
		.a			(decode_rd2),
		.b			(decode_imm),
		.sel		(i_ctrl_inalusel),
		.data_out	(alusrc)
	);
	wire [31:0] aluresult;
	alu U_ALU (
		.rs1			(decode_rd1),
		.rs2			(alusrc),
		.alu_control	(i_ctrl_aluctrl),
		.alu_result		(aluresult)
	);
	assign o_btaken = aluresult[0];
	wire [31:0] pc, pc_pc4, pc_pcaimm;
	pc_logic U_PC_LOGIC (
		.clk				(clk),
		.rst				(rst),
		.i_ctrl_pcupdate	(i_ctrl_pcupdate),
		.i_ctrl_nextpcsel	(i_ctrl_nextpcsel),
		.imm				(decode_imm),
		.alu_result			(aluresult),
		.instr_addr			(pc),
		.pc_add_imm			(pc_pcaimm),
		.pc_add4			(pc_pc4)
	);
	assign instr_addr = pc;
	wire [95:0] exec_reg_out;
	wire [31:0] exec_aluresult, exec_pcimm, exec_pcadd4;
	stage_register #(.WIDHT(96)) U_EXECUTE_STAGE_REG (
		.clk(clk),
		.rst(rst),
		.en(i_state_family[2]),
		.data_in({pc_pc4, pc_pcaimm, aluresult}),
		.data_out(exec_reg_out)
	);
	assign exec_aluresult = exec_reg_out[31:0];
	assign exec_pcimm = exec_reg_out[63:32];
	assign exec_pcadd4 = exec_reg_out[95:64];

	// MEMORY Stage
	wire [31:0] dmem_rdata;
	assign d_addr = exec_aluresult;
	assign dw_data = decode_rd2;
	assign dmem_rdata = dr_data;
	wire [31:0] mem_reg_out, mem_rdata;
	stage_register #(.WIDHT(32)) U_MEMORY_STAGE_REG (
		.clk(clk),
		.rst(rst),
		.en(i_state_family[3]),
		.data_in(dmem_rdata),
		.data_out(mem_reg_out)
	);
	assign mem_rdata = mem_reg_out;

	// WRITEBACK Stage
	mux5_32bit U_RF_WRITE_SRC (
		.d0			(exec_aluresult),
		.d1			(mem_rdata),
		.d2			(exec_pcadd4),
		.d3			(decode_imm),
		.d4			(exec_pcimm),
		.sel		(i_ctrl_rfsrcsel),
		.data_out	(rfsrc)
	);

endmodule

module stage_register #(
	parameter WIDHT = 32
) (
	input 						clk,
	input 						rst,
	input 						en,
	input [WIDHT-1:0] 			data_in,
	output logic [WIDHT-1:0] 	data_out
);
	always_ff @(posedge clk, posedge rst) begin
		if (rst) begin
			data_out <= 0;
		end
		else begin
			if (en) data_out <= data_in;
		end
	end

endmodule

module register_file (
	input 			clk,
	input 			rst,
	input [4:0] 	RA1,    // instruction code RS1
	input [4:0] 	RA2,    // instruction code RS2
	input [4:0] 	WA,     // instruction code RD
	input [31:0] 	Wdata,
	input			rf_we,
	output [31:0] 	RD1,
	output [31:0] 	RD2
);

	logic [31:0]	reg_one [1:31];
	int i;

	assign RD1 = (RA1 == 5'd0)? 32'b0 : reg_one[RA1];
	assign RD2 = (RA2 == 5'd0)? 32'b0 : reg_one[RA2];

`ifdef SIMULATION
	initial begin
		for (i = 1; i < 32; i++) begin
			reg_one[i] = i;
		end
	end
`endif

	always_ff @(posedge clk/*, posedge rst*/) begin
		if (~rst & rf_we) begin
    		if (WA != 0) reg_one[WA] = Wdata;
		end
	end

endmodule

module alu (
	input [31:0] 			rs1,
	input [31:0] 			rs2,
	input [3:0] 			alu_control,
	output logic [31:0] 	alu_result
);

	always_comb begin
		case(alu_control)
			`ALU_CMD_ADD: begin
				alu_result = rs1 + rs2;
			end
			`ALU_CMD_SUB: begin
				alu_result = rs1 - rs2;
			end
			`ALU_CMD_AND: begin
				alu_result = rs1 & rs2;
			end
			`ALU_CMD_OR : begin
				alu_result = rs1 | rs2;
			end
			`ALU_CMD_XOR: begin
				alu_result = rs1 ^ rs2;
			end
			`ALU_CMD_SLT: begin
				alu_result = ( $signed(rs1) < $signed(rs2) )? 32'd1 : 32'b0; // Signed
			end
			`ALU_CMD_SLTU: begin
				alu_result = ( rs1 < rs2 )? 32'd1 : 32'b0; // Unsigned
			end
			`ALU_CMD_SLL: begin
				alu_result = rs1 << rs2[4:0]; // Shift Left
			end
			`ALU_CMD_SRL: begin
				alu_result = rs1 >> rs2[4:0]; // Shift Right
			end
			`ALU_CMD_SRA: begin
				alu_result = $signed(rs1) >>> rs2[4:0]; // Shift Right Arithmetic
			end

			`ALU_CMD_EQ:  begin
				alu_result = ( rs1 == rs2 )? 32'd1 : 32'b0;
			end
			`ALU_CMD_NE:  begin
				alu_result = ( rs1 != rs2 )? 32'd1 : 32'b0;
			end
			`ALU_CMD_GE:  begin
				alu_result = ( $signed(rs1) >= $signed(rs2) )? 32'd1 : 32'b0;
			end
			`ALU_CMD_GEU: begin
				alu_result = ( rs1 >= rs2 )? 32'd1 : 32'b0;
			end

			default: begin
				alu_result = 32'b0;
			end
		endcase
	end

endmodule

module pc_logic (
	input clk,
	input rst,
	input i_ctrl_pcupdate,
	input [1:0] i_ctrl_nextpcsel,
	input [31:0] imm,
	input [31:0] alu_result,
	output [31:0] instr_addr,
	output [31:0] pc_add_imm,
	output [31:0] pc_add4
);
	
	logic [31:0] pc_instr_addr, pc_instr_addr_new, w_pc_add_4, w_pc_add_imm;
	logic [1:0] new_pc_sel;
	assign instr_addr = pc_instr_addr;
	assign pc_add_imm = w_pc_add_imm;
	assign pc_add4 = w_pc_add_4;
	assign new_pc_sel = i_ctrl_nextpcsel;

	pc_alu U_PC_ADD_4 (
		.a(pc_instr_addr),
		.b(32'd4),
		.s(w_pc_add_4)
	);

	pc_alu U_PC_ADD_IMM (
		.a(pc_instr_addr),
		.b(imm),
		.s(w_pc_add_imm)
	);

	mux4_32bit U_NEW_PC (
		.d0(w_pc_add_4),
		.d1(w_pc_add_imm),
		.d2(alu_result),
		.d3(w_pc_add_imm),
		.sel(new_pc_sel),
		.data_out(pc_instr_addr_new)
	);

	pc_reg U_PC_REG (
		.clk(clk),
		.rst(rst),
		.update(i_ctrl_pcupdate),
		.instr_addr_new(pc_instr_addr_new),
		.instr_addr(pc_instr_addr)
	);

endmodule

module pc_reg (
	input clk,
	input rst,
	input update,
	input [31:0] instr_addr_new,
	output [31:0] instr_addr
);

	logic [31:0] program_counter;
	always_ff @(posedge clk, posedge rst) begin
		if (rst) begin
			program_counter <= 32'b0;
		end
		else begin
			if (update == 1'b1) program_counter <= instr_addr_new;
			else program_counter <= program_counter;
		end
	end

	assign instr_addr = program_counter;

endmodule

module pc_alu (
	input [31:0] a,
	input [31:0] b,
	output [31:0] s	
);
	
	assign s = a + b;	

endmodule

module imm_extender (
	input [31:0] instr_code,
	output logic [31:0] data_out
);

	always_comb begin
		data_out = 0;

		case(instr_code[6:0])
			`S_TYPE: data_out = { {20{instr_code[31]}}, instr_code[31:25], instr_code[11:7] };
			`I_TYPE_STORE, `I_TYPE_ALU, `J_TYPE_JALR: data_out = { {20{instr_code[31]}}, instr_code[31:20] };
			`B_TYPE: data_out = { {20{instr_code[31]}},	instr_code[7], instr_code[30:25], instr_code[11:8], 1'b0 };
			`U_TYPE_LUI, `U_TYPE_AUIPC : data_out = { instr_code[31:12], {12{1'b0}} };
			`J_TYPE_JAL: data_out = { {12{instr_code[31]}}, instr_code[19:12], instr_code[20], instr_code[30:21], 1'b0 };
		endcase
	end

endmodule

module mux_32bit (
	input [31:0] 	a,
	input [31:0] 	b,
	input 			sel,
	output [31:0]	data_out
);

	assign data_out = (sel)? b : a;

endmodule

module mux4_32bit (
	input [31:0] 	d0,
	input [31:0] 	d1,
	input [31:0] 	d2,
	input [31:0] 	d3,
	input [1:0]		sel,
	output [31:0]	data_out
);

	assign data_out = (sel == 2'd0)? d0 :
					  (sel == 2'd1)? d1 :
					  (sel == 2'd2)? d2 :
					  (sel == 2'd3)? d3 :32'b0;

endmodule

module mux5_32bit (
	input [31:0] 	d0,
	input [31:0] 	d1,
	input [31:0] 	d2,
	input [31:0] 	d3,
	input [31:0] 	d4,
	input [2:0]		sel,
	output [31:0]	data_out
);

	assign data_out = (sel == 3'd0)? d0 :
					  (sel == 3'd1)? d1 :
					  (sel == 3'd2)? d2 :
					  (sel == 3'd3)? d3 : 
					  (sel == 3'd4)? d4 :32'b0;

endmodule
