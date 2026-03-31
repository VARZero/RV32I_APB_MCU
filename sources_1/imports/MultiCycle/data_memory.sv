`timescale 1ns / 1ps
`include "define.vh"

module data_mem(
    input clk,
    input rst,
    input we,
    input [2:0] funct3,
    input [31:0] addr,
    input [31:0] wdata,
    output logic [31:0] rdata
);
    /* // Byte Addressing
    logic [7:0] dmem [0:31];

    always_ff @(posedge clk) begin
        if (we) begin
            dmem[addr] <= wdata[7:0];
            dmem[addr+1] <= wdata[15:8];
            dmem[addr+2] <= wdata[23:16];
            dmem[addr+3] <= wdata[31:24];
        end
    end

    assign rdata = { dmem[addr+3], dmem[addr+2], dmem[addr+1], dmem[addr] };
    */

    // Word Addressing
    logic [31:0] insert_data, outmem;

    ram U_RAM(
        .clk    (clk),
        .rst    (rst),
        .we     (we),
        .addr   (addr),
        .wdata  (insert_data),
        .rdata  (outmem)
    );

    always_comb begin
        insert_data = 0; rdata = outmem;
        
        if (we) begin
            case({funct3[1:0], addr[1:0]})
                // SB
                4'b00_00: insert_data = {outmem[31:8], wdata[7:0]};
                4'b00_01: insert_data = {outmem[31:16], wdata[7:0], outmem[7:0]};
                4'b00_10: insert_data = {outmem[31:24], wdata[7:0], outmem[15:0]};
                4'b00_11: insert_data = {wdata[7:0], outmem[23:0]};

                // SH
                4'b01_00, 4'b01_01: insert_data = {outmem[31:16], wdata[15:0]};
                4'b01_10, 4'b01_11: insert_data = {wdata[15:0], outmem[15:0]};

                // SW
                4'b10_00, 4'b10_01, 4'b10_10, 4'b10_11: insert_data = wdata;
            endcase
        end
        else begin
            case({funct3[1:0], addr[1:0]})
                // LB
                4'b00_00: rdata = {(funct3[2])? 24'b0 : {24{outmem[7]}}, outmem[7:0]};
                4'b00_01: rdata = {(funct3[2])? 24'b0 : {24{outmem[15]}}, outmem[15:8]};
                4'b00_10: rdata = {(funct3[2])? 24'b0 : {24{outmem[23]}}, outmem[23:16]};
                4'b00_11: rdata = {(funct3[2])? 24'b0 : {24{outmem[31]}}, outmem[31:24]};

                // LH
                4'b01_00, 4'b01_01: rdata = {(funct3[2])? 16'b0 : {16{outmem[15]}}, outmem[15:0]};
                4'b01_10, 4'b01_11: rdata = {(funct3[2])? 16'b0 : {16{outmem[31]}}, outmem[31:16]};

                // SW
                4'b10_00, 4'b10_01, 4'b10_10, 4'b10_11: rdata = outmem;
            endcase

            `ifdef SIMULATION
            	
                if (addr[31:2] > 30'd255) begin
                    $display("a");
                    case(funct3[1:0])
                        2'b00: rdata = {24'b0, 2'b11, addr[7:2]};
                        2'b01: rdata = {16'b0, 2'b11, addr[17:2]};
                        2'b10: rdata = {2'b11, addr[31:2]};
                    endcase
                end
            `endif


        end
        
    end

endmodule

module ram (
    input clk,
    input we,
    input [31:0] addr,
    input [31:0] wdata,
    output logic [31:0] rdata
);
    logic [31:0] dmem [0:1023];
    
    assign rdata = dmem[addr[31:2]];

    always_ff @( posedge clk ) begin
        if (we) begin
            dmem[addr[31:2]] <= wdata;
        end
    end
endmodule

module apb_slave_ram (
    input               PCLK,
    input               PRESET,
    input [31:0]        PADDR,
    input [31:0]        PWDATA,
    input               PWRITE,
    input               PENABLE,
    input               PSEL,
    output logic [31:0] PRDATA,
    output logic        PREADY,

    output logic        we,
    output logic [31:0] addr,
    output logic [31:0] wdata,
    input [31:0]        rdata
);
    // States
    typedef enum logic {IDLE, SEL} state;
    state c_state, n_state;
    
    // Register
    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin c_state <= IDLE; end
        else begin c_state <= n_state; end
    end

    // Next Logic
    always_comb begin
        case(c_state)
            IDLE: begin
                if (PSEL) n_state = SEL;
                else n_state = IDLE;
            end
            SEL: begin
                if (PENABLE) n_state = IDLE;
                else n_state = SEL;
            end
        endcase
    end

    // Output
    always_comb begin
        case(c_state)
            IDLE: begin
                we      = 0;
                addr    = 0;
                wdata   = 0;
                PRDATA  = 0;
                PREADY  = 0;
            end
            SEL: begin
                we      = PWRITE & PENABLE;
                addr    = {20'b0, PADDR[11:0]};
                wdata   = PWDATA;
                PRDATA  = rdata;
                PREADY  = PENABLE;
            end
        endcase
    end

endmodule

module apb_slave #(
    parameter READY_OUT_USE_CYCLE = 1,
    parameter READY_OUT_CYCLE = 1
) (
    input               PCLK,
    input               PRESET,
    input [31:0]        PADDR,
    input [31:0]        PWDATA,
    input               PWRITE,
    input               PENABLE,
    input               PSEL,
    output logic [31:0] PRDATA,
    output logic        PREADY
);

endmodule
