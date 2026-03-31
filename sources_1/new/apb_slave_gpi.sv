`timescale 1ns / 1ps

module apb_slave_gpi(
    input               PCLK,
    input               PRESET,
    input [31:0]        PADDR,
    input [31:0]        PWDATA,
    input               PWRITE,
    input               PENABLE,
    input               PSEL,
    output logic        PREADY,
    output [31:0]       PRDATA,

    input  [15:0]       gpi_in
);
    // Address
    localparam [11:0] GPI_CTL_ADDR = 12'h000;
    localparam [11:0] GPI_IDATA_ADDR = 12'h004;

    // Led Out Register
    logic [15:0]        gpi_ctl_reg, gpi_ctl_next;
    //logic [15:0]        gpi_idata_reg, gpi_idata_next;

    // States
    typedef enum logic {IDLE, UPDATE} state;
    state c_state, n_state;
    
    // Register
    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            c_state <= IDLE;
            gpi_ctl_reg <= 0;
            //gpi_idata_reg <= 0;
        end
        else begin
            c_state <= n_state;
            gpi_ctl_reg <= gpi_ctl_next;
            //gpi_idata_reg <= gpi_idata_next;
        end
    end

    // Next Logic
    always_comb begin
        gpi_ctl_next    = gpi_ctl_reg;

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
                            GPI_CTL_ADDR  : gpi_ctl_next = PWDATA[15:0];
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

    assign PRDATA = (PADDR[11:0] == GPI_CTL_ADDR)? {16'b0, gpi_ctl_reg} :
                    (PADDR[11:0] == GPI_IDATA_ADDR)? {16'b0, gpi_in/*gpi_idata_reg*/} : 32'b0;
/*
    genvar target_led;
    generate
        for (target_led = 0; target_led < 16; target_led++) begin
            assign gpi_idata_next[target_led] 
                        = (gpi_ctl_reg[target_led])? gpi_in[target_led] : 1'bz;
        end
    endgenerate
*/
endmodule
