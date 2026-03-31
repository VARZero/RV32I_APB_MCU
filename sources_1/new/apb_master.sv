`timescale 1ns / 1ps
module apb_master(
    input PCLK,
    input PRESET,

    input [31:0] Addr,
    input [31:0] Wdata,

    input WREQ,
    input RREQ,

    output logic SlvERR,
    output logic [31:0] Rdata,
    output logic Ready,

    output logic [31:0] PADDR,
    output logic [31:0] PWDATA,
    
    output logic [5:0] PSEL,
    output logic       PENABLE,
    output logic       PWRITE,

    input PSlvERR0,
    input [31:0] PRDATA0,
    input PREADY0,

    input PSlvERR1,
    input [31:0] PRDATA1,
    input PREADY1,

    input PSlvERR2,
    input [31:0] PRDATA2,
    input PREADY2,

    input PSlvERR3,
    input [31:0] PRDATA3,
    input PREADY3,

    input PSlvERR4,
    input [31:0] PRDATA4,
    input PREADY4,
    
    input PSlvERR5,
    input [31:0] PRDATA5,
    input PREADY5
);

    // State
    typedef enum logic [1:0] {IDLE, SETUP, ACCESS} state;

    // Registers
    logic [1:0]     c_state, n_state;
    logic           r_wreq, n_wreq;
    logic [31:0]    r_addr, n_addr;
    logic [31:0]    r_wdata, n_wdata;
    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            c_state = IDLE;
            r_wreq  = 0;
            r_addr  = 0;
            r_wdata = 0;
        end
        else begin
            c_state = n_state;
            r_wreq = n_wreq;
            r_addr = n_addr;
            r_wdata = n_wdata;
        end
    end

    // SPECIAL LOGIC: ADDRESS DECODER
    typedef enum logic [2:0] {RAM, GPO, GPI, GPIO, FND, UART} slave_type;
    reg [2:0] target_slave;
    always_comb begin
        target_slave = 3'd7;
        case(r_addr[31:28])
            4'b0000: target_slave = 3'd7; // ROM (is not access this system)
            4'b0001: target_slave = 3'd0; // RAM
            4'b0010: begin
                case(r_addr[15:12])
                    4'd0: target_slave = 3'd1; // GPO
                    4'd1: target_slave = 3'd2; // GPI
                    4'd2: target_slave = 3'd3; // GPIO
                    4'd3: target_slave = 3'd4; // FND
                    4'd4: target_slave = 3'd5; // UART
                endcase
            end
        endcase
    end

    // SPECIAL LOGIC: SLAVE OUTPUT SELECTOR(MUX)
    reg target_slvready, target_slverr; 
    reg [31:0] target_slvrdata;
    always_comb begin
        target_slvready = 0;
        target_slverr = 0;
        target_slvrdata = 0;
        case(target_slave)
            RAM : begin
                target_slvready = PREADY0;
                target_slverr = PSlvERR0;
                target_slvrdata = PRDATA0;
            end // RAM
            GPO : begin
                target_slvready = PREADY1; 
                target_slverr = PSlvERR1;
                target_slvrdata = PRDATA1;
            end // GPO
            GPI : begin
                target_slvready = PREADY2; 
                target_slverr = PSlvERR2;
                target_slvrdata = PRDATA2;
            end // GPI
            GPIO: begin
                target_slvready = PREADY3; 
                target_slverr = PSlvERR3;
                target_slvrdata = PRDATA3;
            end // GPIO
            FND : begin 
                target_slvready = PREADY4;
                target_slverr = PSlvERR4;
                target_slvrdata = PRDATA4;
            end // FND
            UART: begin
                target_slvready = PREADY5;
                target_slverr = PSlvERR5;
                target_slvrdata = PRDATA5;
            end // UART
        endcase
    end

    // State Transition
    always_comb begin
        n_state = c_state;
        n_wreq = r_wreq;
        n_addr = r_addr;
        n_wdata = r_wdata;

        case(c_state)
            IDLE: begin
                if (WREQ || RREQ) begin
                    n_state = SETUP;
                    n_wreq = WREQ;
                    n_addr = Addr;
                    n_wdata = Wdata;
                end
                else n_state = IDLE;
            end
            SETUP: n_state = ACCESS;
            ACCESS: begin
                if (target_slvready) begin
                    n_state = IDLE;
                    /*
                    if (WREQ || RREQ) begin
                        n_state = SETUP;
                        n_wreq = WREQ;
                        n_addr = Addr;
                        n_wdata = Wdata;
                    end
                    else n_state = IDLE;
                    */
                end
                else n_state = ACCESS;
            end
        endcase
    end

    // State Output
    always_comb begin
        PADDR = 0;
        PWDATA = 0;

        SlvERR = 0;
        Rdata = 0;
        Ready = 0;

        PSEL = 0;
        PENABLE = 0;
        PWRITE = 0;

        case(c_state)
            SETUP: begin
                PADDR = r_addr;
                PWDATA = r_wdata;
                PWRITE = r_wreq;
                case(target_slave)
                    RAM : begin
                        PSEL = 6'b000001;
                    end
                    GPO : begin
                        PSEL = 6'b000010;
                    end
                    GPI : begin
                        PSEL = 6'b000100;
                    end
                    GPIO: begin
                        PSEL = 6'b001000;
                    end
                    FND : begin
                        PSEL = 6'b010000;
                    end
                    UART: begin
                        PSEL = 6'b100000;
                    end
                endcase
            end
            ACCESS: begin
                PADDR = r_addr;
                PWDATA = r_wdata;

                Rdata = (r_wreq)? 0 : target_slvrdata;
                SlvERR = target_slverr;
                Ready = target_slvready;
                PENABLE = 1'b1;
                PWRITE = r_wreq;

                case(target_slave)
                    RAM : begin
                        PSEL = 6'b000001;
                    end
                    GPO : begin
                        PSEL = 6'b000010;
                    end
                    GPI : begin
                        PSEL = 6'b000100;
                    end
                    GPIO: begin
                        PSEL = 6'b001000;
                    end
                    FND : begin
                        PSEL = 6'b010000;
                    end
                    UART: begin
                        PSEL = 6'b100000;
                    end
                endcase
            end
        endcase 
    end

endmodule
