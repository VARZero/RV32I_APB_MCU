`define SIMULATION 1
`undef SIMULATION

// INST
`define R_TYPE          7'b0110011
`define S_TYPE          7'b0100011
`define I_TYPE_STORE    7'b0000011
`define I_TYPE_ALU      7'b0010011
`define B_TYPE          7'b1100011
`define U_TYPE_LUI      7'b0110111
`define U_TYPE_AUIPC    7'b0010111
`define J_TYPE_JAL      7'b1101111
`define J_TYPE_JALR     7'b1100111

`define FUNCT3_ALU_ADD_SUB 3'b000
`define FUNCT3_ALU_SLL 	   3'b001
`define FUNCT3_ALU_SLT 	   3'b010
`define FUNCT3_ALU_SLTU    3'b011
`define FUNCT3_ALU_XOR 	   3'b100
`define FUNCT3_ALU_SRL_SRA 3'b101
`define FUNCT3_ALU_OR	   3'b110
`define FUNCT3_ALU_AND 	   3'b111

`define FUNCT_BRANCH_BEQ   3'b000
`define FUNCT_BRANCH_BNE   3'b001
`define FUNCT_BRANCH_BLT   3'b100
`define FUNCT_BRANCH_BGE   3'b101
`define FUNCT_BRANCH_BLTU  3'b110
`define FUNCT_BRANCH_BGEU  3'b111

`define FUNCT7_ALU_ADD 7'b0000000
`define FUNCT7_ALU_SUB 7'b0100000
`define FUNCT7_ALU_SRL 7'b0000000
`define FUNCT7_ALU_SRA 7'b0100000

// ALU CONTROL COMMAND
`define ALU_CMD_ADD  4'b0_000
`define ALU_CMD_SUB  4'b1_000
`define ALU_CMD_SLL  4'b0_001
`define ALU_CMD_SLT  4'b0_010
`define ALU_CMD_SLTU 4'b0_011
`define ALU_CMD_XOR  4'b0_100
`define ALU_CMD_SRL  4'b0_101
`define ALU_CMD_SRA  4'b1_101
`define ALU_CMD_OR 	 4'b0_110
`define ALU_CMD_AND  4'b0_111

`define ALU_CMD_EQ   4'b1_001
`define ALU_CMD_NE   4'b1_010
`define ALU_CMD_LT   4'b0_010 // ALU_CMD_SLT
`define ALU_CMD_GE   4'b1_110
`define ALU_CMD_LTU  4'b0_011 // ALU_CMD_SLTU
`define ALU_CMD_GEU  4'b1_111