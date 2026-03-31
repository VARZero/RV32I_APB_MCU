`timescale 1ns / 1ps
`include "define.vh"

module rv32i_cpu(
	input			clk,
	input 			rst,
	input [31:0]	instr_data,
	input [31:0] 	bus_rdata,
	input			bus_ready,
	output [31:0]	instr_addr,
	output 			rreq,
	output			wreq,
	output [31:0] 	bus_addr,
	output [31:0] 	bus_wdata,
	output [2:0]	d_mem_width
);
	logic [2:0]		d_width;
	logic 			btaken;
	logic [3:0]		state_family;
	logic 			ctrl_inalusel;
	logic [1:0] 	ctrl_nextpcsel;
	logic 			ctrl_pcupdate;
	logic [3:0] 	ctrl_aluctrl;
	logic 			ctrl_dre;
	logic 			ctrl_dwe;
	logic [2:0]		ctrl_rfsrcsel;
	logic 			ctrl_rfwe;

	// Instruction Split
	wire [6:0] inst_opcode;
	wire [2:0] inst_funct3;
	wire [6:0] inst_funct7;
	assign inst_opcode = instr_data[6:0];
	assign inst_funct3 = instr_data[14:12];
	assign inst_funct7 = instr_data[31:25];

	control_unit U_CTRL_UNIT (
		.clk				(clk),
		.rst				(rst),
		.funct7				(inst_funct7),
		.funct3				(inst_funct3),
		.opcode				(inst_opcode),
		.i_btaken			(btaken),
		.i_bus_ready		(bus_ready),
		.o_state_family		(state_family),
		.o_ctrl_inalusel	(ctrl_inalusel),
		.o_ctrl_nextpcsel	(ctrl_nextpcsel),
		.o_ctrl_pcupdate	(ctrl_pcupdate),
		.o_ctrl_aluctrl		(ctrl_aluctrl),
		.o_ctrl_dre			(ctrl_dre),
		.o_ctrl_dwe			(ctrl_dwe),
		.o_ctrl_rfsrcsel	(ctrl_rfsrcsel),
		.o_ctrl_rfwe		(ctrl_rfwe)
	);

	rv32i_datapath U_DP (
	    .clk				(clk),
	    .rst				(rst),
	    .instr_data			(instr_data),
		.dr_data			(bus_rdata),
	    .instr_addr			(instr_addr),
		.d_addr				(bus_addr),
		.dw_data			(bus_wdata),
		.d_width			(d_width),
		.o_btaken			(btaken),
		.i_state_family		(state_family),
		.i_ctrl_inalusel	(ctrl_inalusel),
		.i_ctrl_nextpcsel	(ctrl_nextpcsel),
		.i_ctrl_pcupdate	(ctrl_pcupdate),
		.i_ctrl_aluctrl		(ctrl_aluctrl),
		.i_ctrl_dwe			(ctrl_dwe),
		.i_ctrl_rfsrcsel	(ctrl_rfsrcsel),
		.i_ctrl_rfwe		(ctrl_rfwe)
	);

	assign d_mem_width = d_width;
	assign wreq = ctrl_dwe;
	assign rreq = ctrl_dre;

endmodule

module control_unit (
	input 					clk,
	input 					rst,
	input 		 [6:0] 		funct7,
	input 		 [2:0] 		funct3,
	input 		 [6:0] 		opcode,
	input					i_btaken,
	input					i_bus_ready,
	output logic [3:0]		o_state_family,
	output logic 			o_ctrl_inalusel, // use PC MUX
	output logic [1:0] 		o_ctrl_nextpcsel,
	output logic 			o_ctrl_pcupdate,
	output logic [3:0] 		o_ctrl_aluctrl,
	output logic 			o_ctrl_dre,
	output logic 			o_ctrl_dwe,
	output logic [2:0]		o_ctrl_rfsrcsel,
	output logic 			o_ctrl_rfwe
); 
	reg [3:0] c_state, n_state;

	typedef enum logic [3:0] 
		{ FETCH, DECODE,
		  EXEC_R, EXEC_I, EXEC_U, EXEC_J, EXEC_B, EXEC_L, EXEC_S,
		  MEM_R, MEM_W,
		  WB_ALU, WB_LUI, WB_AUIPC, WB_J, WB_L } state;
	typedef enum logic [3:0] { 
		FETCH_STAGE 	= 4'b0001, 
		DECODE_STAGE 	= 4'b0010, 
		EXECUTE_STAGE 	= 4'b0100, 
		MEMORY_STAGE 	= 4'b1000, 
		WB_STAGE 		= 4'b0000 } stage;

	always_ff @(posedge clk, posedge rst) begin
		if (rst) begin
			c_state <= FETCH;
		end
		else begin
			c_state <= n_state;
		end
	end

	always_comb begin
		// State Transition
		case(c_state)
			FETCH: begin
				n_state = DECODE;
			end
			DECODE: begin
				case(opcode)
					`R_TYPE: begin n_state = EXEC_R; end
					`I_TYPE_ALU: begin n_state = EXEC_I; end
					`U_TYPE_LUI, `U_TYPE_AUIPC: begin n_state = EXEC_U; end
					`J_TYPE_JAL, `J_TYPE_JALR: begin n_state = EXEC_J; end
					`B_TYPE: begin n_state = EXEC_B; end
					`I_TYPE_STORE: begin n_state = EXEC_L; end
					`S_TYPE: begin n_state = EXEC_S; end
					default: begin n_state = 0; end
				endcase
			end

			EXEC_R: begin
				n_state = WB_ALU;
			end
			EXEC_I: begin
				n_state = WB_ALU;
			end
			EXEC_U: begin
				if (opcode == `U_TYPE_LUI) begin n_state = WB_LUI; end
				else if (opcode == `U_TYPE_AUIPC) begin n_state = WB_AUIPC; end
				else begin n_state = 0; end
			end
			EXEC_J: begin
				n_state = WB_J;
			end
			EXEC_B: begin
				n_state = FETCH;
			end
			EXEC_L: begin
				n_state = MEM_R;
			end
			EXEC_S: begin
				n_state = MEM_W;
			end

			MEM_R: begin
				if (i_bus_ready) begin
					n_state = WB_L;
				end
				else begin
					n_state = MEM_R;
				end
			end

			MEM_W: begin
				if (i_bus_ready) begin
					n_state = FETCH;
				end
				else begin
					n_state = MEM_W;
				end
			end

			WB_ALU, WB_LUI, WB_AUIPC, WB_J, WB_L: begin
				n_state = FETCH;
			end

			default: begin n_state = 0; end
		endcase

		// State Output
		case(c_state)
			FETCH: begin
				o_state_family		= FETCH_STAGE;
				o_ctrl_inalusel		= 1'b0;
				o_ctrl_nextpcsel	= 2'b00;
				o_ctrl_pcupdate		= 1'b0;
				o_ctrl_aluctrl		= 4'b0000;
				o_ctrl_dre			= 1'b0;
				o_ctrl_dwe			= 1'b0;
				o_ctrl_rfsrcsel		= 3'b000;
				o_ctrl_rfwe			= 1'b0;
			end 

			DECODE: begin
				o_state_family		= DECODE_STAGE;
				o_ctrl_inalusel		= 1'b0;
				o_ctrl_nextpcsel	= 2'b00;
				o_ctrl_pcupdate		= 1'b0;
				o_ctrl_aluctrl		= 4'b0000;
				o_ctrl_dre			= 1'b0;
				o_ctrl_dwe			= 1'b0;
				o_ctrl_rfsrcsel		= 3'b000;
				o_ctrl_rfwe			= 1'b0;
			end 

			EXEC_R: begin
				o_state_family		= EXECUTE_STAGE;
				o_ctrl_inalusel		= 1'b0; // RS2
				o_ctrl_nextpcsel	= 2'b00; // PC+4
				o_ctrl_pcupdate		= 1'b1; // PC Update
				case(funct3)
					`FUNCT3_ALU_ADD_SUB	: begin 
											if (funct7 == `FUNCT7_ALU_ADD) o_ctrl_aluctrl = `ALU_CMD_ADD; 
											else if (funct7 == `FUNCT7_ALU_SUB) o_ctrl_aluctrl = `ALU_CMD_SUB;
											else o_ctrl_aluctrl = 0;
										  end
					`FUNCT3_ALU_SLL		: begin o_ctrl_aluctrl = `ALU_CMD_SLL; end
					`FUNCT3_ALU_SLT		: begin o_ctrl_aluctrl = `ALU_CMD_SLT; end
					`FUNCT3_ALU_SLTU		: begin o_ctrl_aluctrl = `ALU_CMD_SLTU; end
					`FUNCT3_ALU_XOR		: begin o_ctrl_aluctrl = `ALU_CMD_XOR; end
					`FUNCT3_ALU_SRL_SRA	: begin 
											if (funct7 == `FUNCT7_ALU_SRL) o_ctrl_aluctrl = `ALU_CMD_SRL; 
											else if (funct7 == `FUNCT7_ALU_SRA) o_ctrl_aluctrl = `ALU_CMD_SRA; 
											else o_ctrl_aluctrl = 0;
										  end
					`FUNCT3_ALU_OR		: begin o_ctrl_aluctrl = `ALU_CMD_OR; end
					`FUNCT3_ALU_AND		: begin o_ctrl_aluctrl = `ALU_CMD_AND; end
					default: begin o_ctrl_aluctrl = 0; end
				endcase
				o_ctrl_dre			= 1'b0;
				o_ctrl_dwe			= 1'b0;
				o_ctrl_rfsrcsel		= 3'b000;
				o_ctrl_rfwe			= 1'b0;
			end
			EXEC_I: begin
				o_state_family		= EXECUTE_STAGE;
				o_ctrl_inalusel		= 1'b1; // IMM
				o_ctrl_nextpcsel	= 2'b00; // PC+4
				o_ctrl_pcupdate		= 1'b1; // PC Update
				case(funct3)
					`FUNCT3_ALU_ADD_SUB	: begin o_ctrl_aluctrl = `ALU_CMD_ADD; end
					`FUNCT3_ALU_SLL		: begin o_ctrl_aluctrl = `ALU_CMD_SLL; end
					`FUNCT3_ALU_SLT		: begin o_ctrl_aluctrl = `ALU_CMD_SLT; end
					`FUNCT3_ALU_SLTU		: begin o_ctrl_aluctrl = `ALU_CMD_SLTU; end
					`FUNCT3_ALU_XOR		: begin o_ctrl_aluctrl = `ALU_CMD_XOR; end
					`FUNCT3_ALU_SRL_SRA	: begin 
											if (funct7 == `FUNCT7_ALU_SRL) o_ctrl_aluctrl = `ALU_CMD_SRL; 
											else if (funct7 == `FUNCT7_ALU_SRA) o_ctrl_aluctrl = `ALU_CMD_SRA; 
											else o_ctrl_aluctrl = 0;
										  end
					`FUNCT3_ALU_OR		: begin o_ctrl_aluctrl = `ALU_CMD_OR; end
					`FUNCT3_ALU_AND		: begin o_ctrl_aluctrl = `ALU_CMD_AND; end
					default: begin o_ctrl_aluctrl = 0; end
				endcase
				o_ctrl_dre			= 1'b0;
				o_ctrl_dwe			= 1'b0;
				o_ctrl_rfsrcsel		= 3'b000;
				o_ctrl_rfwe			= 1'b0;
			end 
			EXEC_U: begin
				o_state_family		= EXECUTE_STAGE;
				o_ctrl_inalusel		= 1'b0;
				o_ctrl_nextpcsel	= 2'b00; // PC+4
				o_ctrl_pcupdate		= 1'b1; // PC Update
				o_ctrl_aluctrl		= 4'b0000;
				o_ctrl_dre			= 1'b0;
				o_ctrl_dwe			= 1'b0;
				o_ctrl_rfsrcsel		= 3'b000;
				o_ctrl_rfwe			= 1'b0;
			end 
			EXEC_J: begin
				o_state_family		= EXECUTE_STAGE;
				o_ctrl_inalusel		= 1'b1; // IMM
				if (opcode == `J_TYPE_JAL) o_ctrl_nextpcsel = 2'b01; // JAL: PC + IMM
				else if (opcode == `J_TYPE_JALR) o_ctrl_nextpcsel = 2'b10; // JALR: RS1 + IMM
				else o_ctrl_nextpcsel = 2'b01;
				o_ctrl_pcupdate		= 1'b1; // PC Update
				o_ctrl_aluctrl		= `ALU_CMD_ADD;
				o_ctrl_dre			= 1'b0;
				o_ctrl_dwe			= 1'b0;
				o_ctrl_rfsrcsel		= 3'b000;
				o_ctrl_rfwe			= 1'b0;
			end 
			EXEC_B: begin
				o_state_family		= EXECUTE_STAGE;
				o_ctrl_inalusel		= 1'b0; // RS2
				o_ctrl_nextpcsel	= {1'b0, i_btaken}; // follow btaken
				o_ctrl_pcupdate		= 1'b1; // PC Update
				case(funct3)
					`FUNCT_BRANCH_BEQ  : o_ctrl_aluctrl = `ALU_CMD_EQ;
					`FUNCT_BRANCH_BNE  : o_ctrl_aluctrl = `ALU_CMD_NE;
					`FUNCT_BRANCH_BLT  : o_ctrl_aluctrl = `ALU_CMD_LT;
					`FUNCT_BRANCH_BGE  : o_ctrl_aluctrl = `ALU_CMD_GE;
					`FUNCT_BRANCH_BLTU : o_ctrl_aluctrl = `ALU_CMD_LTU;
					`FUNCT_BRANCH_BGEU : o_ctrl_aluctrl = `ALU_CMD_GEU;
					default: begin o_ctrl_aluctrl = 0; end
				endcase
				o_ctrl_dre			= 1'b0;
				o_ctrl_dwe			= 1'b0;
				o_ctrl_rfsrcsel		= 3'b000;
				o_ctrl_rfwe			= 1'b0;
			end 
			EXEC_L: begin
				o_state_family		= EXECUTE_STAGE;
				o_ctrl_inalusel		= 1'b1; // IMM
				o_ctrl_nextpcsel	= 2'b00; // PC+4
				o_ctrl_pcupdate		= 1'b1; // PC Update
				o_ctrl_aluctrl		= `ALU_CMD_ADD;
				o_ctrl_dre			= 1'b0;
				o_ctrl_dwe			= 1'b0;
				o_ctrl_rfsrcsel		= 3'b000;
				o_ctrl_rfwe			= 1'b0;
			end 
			EXEC_S: begin
				o_state_family		= EXECUTE_STAGE;
				o_ctrl_inalusel		= 1'b1; // IMM
				o_ctrl_nextpcsel	= 2'b00; // PC+4
				o_ctrl_pcupdate		= 1'b1; // PC Update
				o_ctrl_aluctrl		= `ALU_CMD_ADD;
				o_ctrl_dre			= 1'b0;
				o_ctrl_dwe			= 1'b0;
				o_ctrl_rfsrcsel		= 3'b000;
				o_ctrl_rfwe			= 1'b0;
			end 

			MEM_R: begin
				o_state_family		= MEMORY_STAGE;
				o_ctrl_inalusel		= 1'b0;
				o_ctrl_nextpcsel	= 2'b00;
				o_ctrl_pcupdate		= 1'b0;
				o_ctrl_aluctrl		= 4'b0000;
				o_ctrl_dre			= 1'b1;
				o_ctrl_dwe			= 1'b0; // Read
				o_ctrl_rfsrcsel		= 3'b000;
				o_ctrl_rfwe			= 1'b0;
			end 
			MEM_W: begin
				o_state_family		= MEMORY_STAGE;
				o_ctrl_inalusel		= 1'b0;
				o_ctrl_nextpcsel	= 2'b00;
				o_ctrl_pcupdate		= 1'b0;
				o_ctrl_aluctrl		= 4'b0000;
				o_ctrl_dre			= 1'b0;
				o_ctrl_dwe			= 1'b1;	// Write
				o_ctrl_rfsrcsel		= 3'b000;
				o_ctrl_rfwe			= 1'b0;
			end 
			
			WB_ALU: begin
				o_state_family		= WB_STAGE;
				o_ctrl_inalusel		= 1'b0;
				o_ctrl_nextpcsel	= 2'b00;
				o_ctrl_pcupdate		= 1'b0;
				o_ctrl_aluctrl		= 4'b0000;
				o_ctrl_dre			= 1'b0;
				o_ctrl_dwe			= 1'b0;
				o_ctrl_rfsrcsel		= 3'd0;	// ALU
				o_ctrl_rfwe			= 1'b1; // Write
			end 
			WB_LUI: begin
				o_state_family		= WB_STAGE;
				o_ctrl_inalusel		= 1'b0;
				o_ctrl_nextpcsel	= 2'b00;
				o_ctrl_pcupdate		= 1'b0;
				o_ctrl_aluctrl		= 4'b0000;
				o_ctrl_dre			= 1'b0;
				o_ctrl_dwe			= 1'b0;
				o_ctrl_rfsrcsel		= 3'd3;	// IMM
				o_ctrl_rfwe			= 1'b1; // Write
			end 
			WB_AUIPC: begin
				o_state_family		= WB_STAGE;
				o_ctrl_inalusel		= 1'b0;
				o_ctrl_nextpcsel	= 2'b00;
				o_ctrl_pcupdate		= 1'b0;
				o_ctrl_aluctrl		= 4'b0000;
				o_ctrl_dre			= 1'b0;
				o_ctrl_dwe			= 1'b0;
				o_ctrl_rfsrcsel		= 3'd4;	// PC+IMM
				o_ctrl_rfwe			= 1'b1; // Write
			end 
			WB_J: begin
				o_state_family		= WB_STAGE;
				o_ctrl_inalusel		= 1'b0;
				o_ctrl_nextpcsel	= 2'b00;
				o_ctrl_pcupdate		= 1'b0;
				o_ctrl_aluctrl		= 4'b0000;
				o_ctrl_dre			= 1'b0;
				o_ctrl_dwe			= 1'b0;
				o_ctrl_rfsrcsel		= 3'd2;	// PC+4
				o_ctrl_rfwe			= 1'b1; // Write
			end 
			WB_L: begin
				o_state_family		= WB_STAGE;
				o_ctrl_inalusel		= 1'b0;
				o_ctrl_nextpcsel	= 2'b00;
				o_ctrl_pcupdate		= 1'b0;
				o_ctrl_aluctrl		= 4'b0000;
				o_ctrl_dre			= 1'b0;
				o_ctrl_dwe			= 1'b0;
				o_ctrl_rfsrcsel		= 3'd1;	// MEM out
				o_ctrl_rfwe			= 1'b1; // Write
			end 
		endcase
	end

endmodule

