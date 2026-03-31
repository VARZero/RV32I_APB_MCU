`timescale 1ns / 1ps
module apb_slave_intf_reg #(
    parameter ADDRESS_MAXIMUM = 'hFFF,
    parameter MUST_UPDATE_AFTER_TRANSACTION = 0,
    parameter NUM_OF_REGISTERS = 12,
    parameter string REG_TYPES = "rwrwrwrwrwrw", // r: Read Only use APB, w: Read and Write use APB
    parameter AVAILABLE_ADDRESS_BITWIDTH = $clog2(NUM_OF_REGISTERS)
) (
    input                                       PCLK,
    input                                       PRESET,
    input [AVAILABLE_ADDRESS_BITWIDTH-1:0]      PADDR,
    input [31:0]                                PWDATA,
    input                                       PWRITE,
    input                                       PENABLE,
    input                                       PSEL,
    output logic [31:0]                         PRDATA,
    output logic                                PREADY,
    output logic                                PSlvERR,

    input [NUM_OF_REGISTERS-1:0]                i_slv_reg_update,
    input [(NUM_OF_REGISTERS*32)-1:0]           i_slv_reg_data,
    output logic [(NUM_OF_REGISTERS*32)-1:0]    o_slv_reg_data
);
    // Properties Define use Parameters
    localparam AVAILABLE_ADDR_AREA_TOP = AVAILABLE_ADDRESS_BITWIDTH - 1; // Available Area

    // Set Register Variables
    logic [NUM_OF_REGISTERS-1:0] update_vector, update_vector_next;
    logic [31:0] internal_reg [0:NUM_OF_REGISTERS-1];
    logic [31:0] internal_reg_next [0:NUM_OF_REGISTERS-1];

    // State Setting
    typedef enum logic [1:0] { IDLE, TRANSFER, WAIT } state;
    state c_state, n_state;

    // Register Modeling
    short reg_init;
    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            c_state <= IDLE;
            update_vector <= 0;
            for (reg_init = 0; reg_init < NUM_OF_REGISTERS; reg_init++) begin
                internal_reg[reg_init] <= 0;
            end
        end
        else begin
            c_state <= n_state;
            update_vector <= update_vector_next;
            for (reg_init = 0; reg_init < NUM_OF_REGISTERS; reg_init++) begin
                internal_reg[reg_init] <= internal_reg_next[reg_init];
            end
        end
    end

    // Register next
    short reg_sel_on_for;
    always_comb begin
        // Initialization Registers
        n_state = c_state;
        update_vector_next = update_vector;
        for (reg_sel_on_for = 0; reg_sel_on_for < NUM_OF_REGISTERS; reg_sel_on_for++) begin
            internal_reg_next[reg_sel_on_for] = internal_reg[reg_sel_on_for];
        end

        // State Transition
        case(c_state)
            IDLE: begin
                if (PSEL) begin
                    if (MUST_UPDATE_AFTER_TRANSACTION) n_state = WAIT;
                    else n_state = TRANSFER;
                end
                else n_state = IDLE;
            end
            TRANSFER: begin
                if (PENABLE) n_state = IDLE;
                else n_state = TRANSFER;
            end
            WAIT: begin
                if ( update_vector[ PADDR[AVAILABLE_ADDRESS_BITWIDTH-1:0] ] )
                    n_state = TRANSFER;
                else n_state = WAIT;
            end
        endcase

        // Update Vector
        case(c_state)
            WAIT: begin
                update_vector_next = i_slv_reg_update;
            end
        endcase

        // Update Registers
        for (reg_sel_on_for = 0; reg_sel_on_for < NUM_OF_REGISTERS; reg_sel_on_for++) begin
            if ((reg_sel_on_for == PADDR[AVAILABLE_ADDRESS_BITWIDTH-1:0]) 
                && (REG_TYPES[reg_sel_on_for] == "w") && (PWRITE && PENABLE))
            begin    
                internal_reg_next[reg_sel_on_for] = PWDATA;
            end
            else begin
                internal_reg_next[reg_sel_on_for]
                    = (i_slv_reg_update[reg_sel_on_for])? 
                        i_slv_reg_data[(reg_sel_on_for*32) +: 32] : internal_reg[reg_sel_on_for];
            end
        end
        
    end

    // Output
    short reg_out_on_for;
    always_comb begin
        // Registers out
        for (reg_out_on_for = 0; reg_out_on_for < NUM_OF_REGISTERS; reg_out_on_for++) begin
            o_slv_reg_data[(32 * reg_out_on_for) +: 32] = internal_reg[reg_out_on_for];
        end

        case(c_state)
            IDLE: begin
                PRDATA  = 0;
                PREADY  = 0;
                PSlvERR = 0;
            end
            TRANSFER: begin
                PRDATA  = internal_reg[ PADDR[AVAILABLE_ADDRESS_BITWIDTH-1:0] ];
                PREADY  = PENABLE;
                if (PWRITE && (PADDR[AVAILABLE_ADDRESS_BITWIDTH-1:0] < ADDRESS_MAXIMUM) ) begin
                    PSlvERR = (REG_TYPES[ PADDR[AVAILABLE_ADDRESS_BITWIDTH-1:0] ] == "w")? 1'b0 : 1'b1;
                end
                else
                    PSlvERR = (PADDR[AVAILABLE_ADDRESS_BITWIDTH-1:0] > ADDRESS_MAXIMUM)? 1'b1 : 1'b0;
            end
            WAIT: begin
                PRDATA  = 0;
                PREADY  = 0;
                PSlvERR = 0;
            end
        endcase

    end

endmodule
