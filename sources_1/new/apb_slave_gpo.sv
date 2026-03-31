`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/26 11:00:53
// Design Name: 
// Module Name: apb_slave_gpo
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module apb_slave_gpo(
    input               PCLK,
    input               PRESET,
    input [31:0]        PADDR,
    input [31:0]        PWDATA,
    input               PWRITE,
    input               PENABLE,
    input               PSEL,
    output logic        PREADY,
    output [31:0]       PRDATA,

    output logic [15:0]  gpo_out
);
    // Address
    localparam [11:0] GPO_CTL_ADDR = 12'h000;
    localparam [11:0] GPO_ODATA_ADDR = 12'h004;

    // Led Out Register
    logic [15:0]        gpo_ctl_reg, gpo_ctl_next;
    logic [15:0]        gpo_odata_reg, gpo_odata_next;

    // States
    typedef enum logic {IDLE, UPDATE} state;
    state c_state, n_state;
    
    // Register
    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            c_state <= IDLE;
            gpo_ctl_reg <= 0;
            gpo_odata_reg <= 0;
        end
        else begin
            c_state <= n_state;
            gpo_ctl_reg <= gpo_ctl_next;
            gpo_odata_reg <= gpo_odata_next;
        end
    end

    // Next Logic
    always_comb begin
        gpo_ctl_next    = gpo_ctl_reg;
        gpo_odata_next  = gpo_odata_reg;

        case(c_state)
            IDLE: begin
                if (PSEL) n_state = UPDATE;
                else n_state = IDLE;
            end
            UPDATE: begin
                if (PENABLE) begin
                    n_state = IDLE;
                    if (PWRITE) begin
                        case(PADDR[11:0])
                            GPO_CTL_ADDR  : gpo_ctl_next      = PWDATA[15:0];
                            GPO_ODATA_ADDR: gpo_odata_next    = PWDATA[15:0];
                        endcase
                    end

                end
                else n_state = UPDATE;
            end
        endcase
    end

    // Output
    always_comb begin
        case(c_state)
            IDLE: begin
                PREADY  = 0;
            end
            UPDATE: begin
                PREADY  = PENABLE;
            end
        endcase

    end

    //assign gpo_out = (gpo_ctl_reg)? gpo_odata_reg : 16'hzzzz;

    assign PRDATA = (PADDR[11:0] == GPO_CTL_ADDR)? {16'b0, gpo_ctl_reg} :
                    (PADDR[11:0] == GPO_ODATA_ADDR)? {16'b0, gpo_odata_reg} : 32'b0;

    genvar target_led;
    generate
        for (target_led = 0; target_led < 16; target_led++) begin
            assign gpo_out[target_led] 
                        = (gpo_ctl_reg[target_led])? gpo_odata_reg[target_led] : 1'bz;
        end
    endgenerate

endmodule

module output_ctrl (
    input  [15:0]  i_led,
    input  [15:0]  i_led_ctrl,
    output [15:0]  o_led
);
    genvar target_led;
    generate
        for (target_led = 0; target_led < 16; target_led++) begin
            assign o_led[target_led] 
                        = (i_led_ctrl[target_led])? i_led[target_led] : 1'bz;
        end
    endgenerate
endmodule
