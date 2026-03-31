`timescale 1ns / 1ps

/*
    tx_start는 버튼_Down (btn_down)
    tx_data = 0x30
*/

/*
module ascii_decoder (
    input [7:0] rx_data,
    input rx_done,
    output reg [7:0] opcode // s_2_1_0_d_u_l_r
);
    always @(*) begin
        if (rx_done) begin
            case (rx_data)
                8'h72:      opcode = 8'b0_0_0_0_0_0_0_1; // r
                8'h6C:      opcode = 8'b0_0_0_0_0_0_1_0; // l
                8'h75:      opcode = 8'b0_0_0_0_0_1_0_0; // u
                8'h64:      opcode = 8'b0_0_0_0_1_0_0_0; // d
                8'h30:      opcode = 8'b0_0_0_1_0_0_0_0; // 0
                8'h31:      opcode = 8'b0_0_1_0_0_0_0_0; // 1
                8'h32:      opcode = 8'b0_1_0_0_0_0_0_0; // 2
                8'h73:      opcode = 8'b1_0_0_0_0_0_0_0; // s
                default:    opcode = 8'b0_0_0_0_0_0_0_0;
            endcase
        end
        else begin
            opcode = 8'b0_0_0_0_0_0_0_0;
        end
    end
endmodule
*/

module uart_sys (
    input           clk,
    input           rst,
    
    // uart_rx -> ascii_decoder
    input           i_uart_rx,
    output [7:0]    o_ascdec_opcode,

    // ascii_sender -> FIFO -> uart_tx
    output          o_uart_tx,
    input [1:0]     i_ctrl_type,
    input [31:0]    i_dpm_data,
    input           i_ctrl_uartsnd
);
    // Wires
        // BAUD TICK
    wire b_tick;
        // RX SIGNALS
    wire [7:0] rx_data;
    wire rx_done;

        // ascii_sender
    wire [7:0] ascsnd_data;
    wire ascsnd_ready;
    wire [7:0] tx_pop_data;

    wire [7:0] rx_pop_data;
    wire rx_full, rx_empty;
    wire tx_full, tx_empty;

    baud_tick_sampling_divide U_BAUD_TICK (
        .clk(clk),
        .rst(rst),
        .b_tick(b_tick)
    );

    // UART RX -> ascii_decoder

    uart_rx U_UART_RX (
        .clk(clk),
        .rst(rst),
        .rx(i_uart_rx),
        .b_tick(b_tick),
        .rx_data(rx_data),
        .rx_done(rx_done)
    );

    fifo #(.DEPTH(32), .BIT_WIDTH(8)) U_FIFO_RX (
        .clk(clk),
        .rst(rst),
        .push(rx_done),
        .pop(1'b1),
        .push_data(rx_data),
        .pop_data(rx_pop_data),
        .full(rx_full),
        .empty(rx_empty)
    );

    ascii_decoder U_ASCII_DECODER(
        .clk(clk),
        .rst(rst),
        .rx_data(rx_pop_data),
        .rx_done(~rx_empty),
        .opcode(o_ascdec_opcode)
    );

    // ascii_sender -> FIFO -> UART TX
    ascii_sender U_ASCII_SENDER (
        .clk(clk),
        .rst(rst),
        .i_fifo_full(tx_full),
        .i_ctrl_uartsnd(i_ctrl_uartsnd),
        .i_ctrl_type(i_ctrl_type),
        .i_dpm_data(i_dpm_data),
        .o_ascii_char(ascsnd_data),
        .o_ready_char(ascsnd_ready)
    );

    fifo #(.DEPTH(32), .BIT_WIDTH(8)) U_FIFO_TX (
        .clk(clk),
        .rst(rst),
        .push(ascsnd_ready),
        .pop(~tx_tx_busy),
        .push_data(ascsnd_data),
        .pop_data(tx_pop_data),
        .full(tx_full),
        .empty(tx_empty)
    );

    uart_tx U_UART_TX (
        .clk(clk),
        .rst(rst),
        .tx_start(~tx_empty),
        .b_tick(b_tick),
        .tx_data(tx_pop_data),
        .tx_busy(tx_tx_busy),
        .tx_done(),
        .uart_tx(o_uart_tx)
    );

endmodule

module ascii_sender (
    input               clk,
    input               rst,
    input               i_fifo_full,
    input               i_ctrl_uartsnd,
    input [1:0]         i_ctrl_type,
    input [31:0]        i_dpm_data,
    output reg [7:0]    o_ascii_char,
    output reg          o_ready_char
);
    // CHAR ROM
    wire [31:0] type_char_rom [0:3];
    assign type_char_rom[0] = 32'h29_20_57_53; // "SW :"
    assign type_char_rom[1] = 32'h29_20_20_57; // "W  :"
    assign type_char_rom[2] = 32'h29_53_49_44; // "DIS:"
    assign type_char_rom[3] = 32'h29_54_2F_48; // "H/T:"

    // DECO ROM
    wire [24:0] deco_rom [0:3];
    assign deco_rom[0] = 25'h1_20_3A_3A; // ":: "
    assign deco_rom[1] = 25'h1_20_3A_3A; // ":: "
    assign deco_rom[2] = 25'h0_00_00_00; // NULL
    assign deco_rom[3] = 25'h1_20_2F_2E; // "./ "

    // DIGIT CHAR ROM
    wire [7:0] digit_char_rom [0:9];
    assign digit_char_rom[0] = 8'h30; // "0"
    assign digit_char_rom[1] = 8'h31; // "1" 
    assign digit_char_rom[2] = 8'h32; // "2"
    assign digit_char_rom[3] = 8'h33; // "3"
    assign digit_char_rom[4] = 8'h34; // "4"
    assign digit_char_rom[5] = 8'h35; // "5"
    assign digit_char_rom[6] = 8'h36; // "6"
    assign digit_char_rom[7] = 8'h37; // "7"
    assign digit_char_rom[8] = 8'h38; // "8"
    assign digit_char_rom[9] = 8'h39; // "9"

    // State
    localparam IDLE = 3'd0, WAIT = 3'd1, TYPE = 3'd2, VALUE = 3'd3, DECO = 3'd4;

    // Registers
    reg [2:0] state, state_next;

    reg [2:0] target_char, target_char_next;
    reg [1:0] type, type_next;
    reg [31:0] data, data_next;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            state <= IDLE;
            
            target_char <= 3'd0;
            type <= 0;
            data <= 0;
        end
        else begin
            state <= state_next;

            target_char <= target_char_next;
            type <= type_next;
            data <= data_next;
        end
    end

    // State Next, Output

    reg [3:0] digit_mux;

    always @(*) begin
        state_next = state;

        target_char_next = target_char;
        type_next = type;
        data_next = data;

        o_ascii_char = 8'b0;
        o_ready_char = 1'b0;

        // Digit<->Data MUX
        case(target_char)
            3'd0: digit_mux = data[31:28];
            3'd1: digit_mux = data[27:24];
            3'd2: digit_mux = data[23:20];
            3'd3: digit_mux = data[19:16];
            3'd4: digit_mux = data[15:12];
            3'd5: digit_mux = data[11:8];
            3'd6: digit_mux = data[7:4];
            3'd7: digit_mux = data[3:0];
            default: digit_mux = 4'd0;
        endcase

        // State ~~
        case(state)
            IDLE: begin
                target_char_next = 0;
                type_next = 0;
                data_next = 0;

                if (i_ctrl_uartsnd) begin
                    state_next = WAIT;
                    
                    type_next = i_ctrl_type;
                    data_next = i_dpm_data;
                end
            end
            WAIT: begin
                if (~i_fifo_full) begin
                    state_next = TYPE;

                    data_next[3:0]  =  data[7:0]    % 10;
                    data_next[7:4]  = (data[7:0]    / 10) % 10;
                    data_next[11:8] =  data[15:8]   % 10;
                    data_next[15:12]= (data[15:8]   / 10) % 10;
                    data_next[19:16]=  data[23:16]  % 10;
                    data_next[23:20]= (data[23:16]  / 10) % 10;
                    data_next[27:24]=  data[31:24]  % 10;
                    data_next[31:28]= (data[31:24]  / 10) % 10;
                end
            end
            TYPE: begin
                if (~i_fifo_full) begin
                    // Send Type Character
                    case(target_char)
                        3'd0: o_ascii_char = type_char_rom[type][7:0];
                        3'd1: o_ascii_char = type_char_rom[type][15:8];
                        3'd2: o_ascii_char = type_char_rom[type][23:16];
                        3'd3: o_ascii_char = type_char_rom[type][31:24];
                        default: o_ascii_char = 8'b0;
                    endcase
                    o_ready_char = 1'b1;

                    target_char_next = target_char + 1;
                    
                    if (target_char == 3) begin
                        state_next = VALUE;
                        
                        target_char_next = 0;
                    end
                end
            end
            VALUE: begin
                if (~i_fifo_full) begin
                    o_ascii_char = digit_char_rom[digit_mux];
                    o_ready_char = 1'b1;

                    target_char_next = target_char + 1;
                    
                    if (target_char[0] == 1'b1) begin
                        state_next = DECO;
                    end
                end
            end
            DECO: begin
                if (~i_fifo_full) begin
                    state_next = VALUE;

                    o_ready_char = deco_rom[type][24];
                    
                    if (target_char == 3'd0) begin
                        state_next = IDLE;

                        o_ascii_char = deco_rom[type][23:16];
                    end
                    else if (target_char[2:1] == 2'd2) begin
                        o_ascii_char = deco_rom[type][15:8];
                    end
                    else begin
                        o_ascii_char = deco_rom[type][7:0];
                    end
                end
            end
        endcase
    end

endmodule

module ascii_decoder (
    input clk,
    input rst,
    input [7:0] rx_data,
    input rx_done,
    output [7:0] opcode // s_2_1_0_d_u_l_r
);
    reg state, state_next;
    reg [7:0] data, data_next;
    reg [7:0] opcode_reg, opcode_next;

    // States
    parameter IDLE = 1'b0;
    parameter ACTIVE = 1'b1;

    assign opcode = opcode_reg;

    // Register
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= 1'b0;
            data <= 8'b0;
            opcode_reg <= 8'b0;
        end
        else begin
            state <= state_next;
            data <= data_next;
            opcode_reg <= opcode_next;
        end
    end

    // State Transition
    always @(*) begin
        state_next = state;
        case(state)
            IDLE: begin
                if (rx_done) state_next = ACTIVE;
                else state_next = IDLE;
            end
            ACTIVE: begin
                if (rx_done) state_next = ACTIVE;
                else state_next = IDLE;
            end
        endcase
    end

    // State Output
    always @(*) begin
        data_next = (rx_done)? rx_data : 0;
        if (state == IDLE) begin
            opcode_next = 8'b0_0_0_0_0_0_0_0;
        end
        else if (state == ACTIVE) begin
            case (data)
                8'h72:      opcode_next = 8'b0_0_0_0_0_0_0_1; // r
                8'h6C:      opcode_next = 8'b0_0_0_0_0_0_1_0; // l
                8'h75:      opcode_next = 8'b0_0_0_0_0_1_0_0; // u
                8'h64:      opcode_next = 8'b0_0_0_0_1_0_0_0; // d
                8'h30:      opcode_next = 8'b0_0_0_1_0_0_0_0; // 0
                8'h31:      opcode_next = 8'b0_0_1_0_0_0_0_0; // 1
                8'h32:      opcode_next = 8'b0_1_0_0_0_0_0_0; // 2
                8'h73:      opcode_next = 8'b1_0_0_0_0_0_0_0; // s
                default:    opcode_next = 8'b0_0_0_0_0_0_0_0;
            endcase
        end
    end
endmodule

module ascii_digit_transfer (
    input [3:0] i_digit,
    output reg [7:0] o_ascii
);
    localparam ASCII_0 = 8'h30;
    localparam ASCII_1 = 8'h31;
    localparam ASCII_2 = 8'h32;
    localparam ASCII_3 = 8'h33;
    localparam ASCII_4 = 8'h34;
    localparam ASCII_5 = 8'h35;
    localparam ASCII_6 = 8'h36;
    localparam ASCII_7 = 8'h37;
    localparam ASCII_8 = 8'h38;
    localparam ASCII_9 = 8'h39;

    always @(*) begin
        case(i_digit)
            0: o_ascii = ASCII_0;
            1: o_ascii = ASCII_1;
            2: o_ascii = ASCII_2;
            3: o_ascii = ASCII_3;
            4: o_ascii = ASCII_4;
            5: o_ascii = ASCII_5;
            6: o_ascii = ASCII_6;
            7: o_ascii = ASCII_7;
            8: o_ascii = ASCII_8;
            9: o_ascii = ASCII_9;
            default: o_ascii = 0;
        endcase
    end

endmodule

module ascii_sender_v1 (
    input clk,
    input rst,
    input type_sw_w, // sw: 0, w: 1
    input [23:0] time_value,
    input s_active,
    input tx_busy,
    input tx_done,
    output reg [7:0] new_tx_data,
    output tx_start,
    output running
);

    // Wire spilt
    wire [6:0] msec;
    wire [5:0] sec;
    wire [5:0] min;
    wire [4:0] hour;

    assign msec = time_value[6:0];
    assign sec = time_value[12:7];
    assign min = time_value[18:13];
    assign hour = time_value[23:19];

    // ASCII
    localparam ASCII_COLON = 8'h3A;
    localparam ASCII_DOT = 8'h2E;
    localparam ASCII_S = 8'h53;
    localparam ASCII_W = 8'h57;
    localparam ASCII_SPACE = 8'h20;

    // digit <-> ascii
    reg [3:0] digit;
    wire [7:0] ascii_digit;
    ascii_digit_transfer U_ASCII_2_DIGIT(
        .i_digit(digit),
        .o_ascii(ascii_digit)
    );

    // State
    localparam IDLE = 5'd0, WAIT = 5'd1, START_SPACE = 5'd2;
    localparam ALPHA_S = 5'd3, ALPHA_W = 5'd4;
    localparam COLON = 5'd5, SPACE = 5'd6;
    localparam HOUR_UP = 5'd7, HOUR_LOW = 5'd8, HOUR_COL = 5'd9;
    localparam MIN_UP = 5'd10, MIN_LOW = 5'd11, MIN_COL = 5'd12;
    localparam SEC_UP = 5'd13, SEC_LOW = 5'd14, SEC_DOT = 5'd15;
    localparam MSEC_UP = 5'd16, MSEC_LOW = 5'd17, END_SPACE = 5'd18;

    // State Register
    reg [4:0] state, state_next;
    reg tx_start_reg, tx_start_next;
    reg running_reg, running_next;
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            state <= IDLE;
            tx_start_reg <= 0;
            running_reg <= 0;
        end
        else begin
            state <= state_next;
            tx_start_reg <= tx_start_next;
            running_reg <= running_next;
        end
    end

    // Next State logic
    always @(*) begin
        state_next = state;
        tx_start_next = 1'b0;
        running_next = 1'b0;
        case(state)
            IDLE: begin
                if (s_active) begin
                    running_next = 1'b1;
                    state_next = WAIT;
                end
            end
            WAIT: begin
                running_next = 1'b1;
                if (~tx_busy) begin
                    tx_start_next = 1'b1;
                    state_next = START_SPACE;
                end
            end
            START_SPACE: begin
                running_next = 1'b1;
                if (tx_done) begin
                    tx_start_next = 1'b1;
                    if (type_sw_w == 0) state_next = ALPHA_S;
                    else state_next = ALPHA_W;
                end
            end
            ALPHA_S, ALPHA_W, COLON, SPACE,
            HOUR_UP, HOUR_LOW, HOUR_COL,
            MIN_UP, MIN_LOW, MIN_COL,
            SEC_UP, SEC_LOW, SEC_DOT,
            MSEC_UP, MSEC_LOW: begin
                running_next = 1'b1;
                if (tx_done) begin
                    tx_start_next = 1'b1;
                    state_next = state + 1;
                end
            end
            END_SPACE: begin
                running_next = 1'b1;
                if (tx_done) begin
                    tx_start_next = 1'b1;
                    state_next = IDLE;
                end
            end
        endcase
    end

    // Output logic
    assign tx_start = tx_start_reg;
    assign running = running_reg;

    always @(*) begin
        new_tx_data = 0;
        digit = 0;
        case(state)
            IDLE: new_tx_data = 0;
            ALPHA_S: new_tx_data = ASCII_S;
            ALPHA_W: new_tx_data = ASCII_W;
            COLON, HOUR_COL, MIN_COL: new_tx_data = ASCII_COLON;
            START_SPACE, SPACE, END_SPACE: new_tx_data = ASCII_SPACE;
            SEC_DOT: new_tx_data = ASCII_DOT;
            HOUR_UP: begin
                digit = (hour/10) % 10;
                new_tx_data = ascii_digit;
            end
            HOUR_LOW: begin
                digit = hour % 10;
                new_tx_data = ascii_digit;
            end 
            MIN_UP: begin
                digit = (min/10) % 10;
                new_tx_data = ascii_digit;
            end
            MIN_LOW: begin
                digit = min % 10;
                new_tx_data = ascii_digit;
            end 
            SEC_UP: begin
                digit = (sec/10) % 10;
                new_tx_data = ascii_digit;
            end
            SEC_LOW: begin
                digit = sec % 10;
                new_tx_data = ascii_digit;
            end
            MSEC_UP: begin
                digit = (msec/10) % 10;
                new_tx_data = ascii_digit;
            end
            MSEC_LOW: begin
                digit = msec % 10;
                new_tx_data = ascii_digit;
            end
        endcase
    end
endmodule

module uart_sys_v1 (
    input  clk,
    input  rst,
    input  set_en_tx,
    input  en_tx_start,
    input  [7:0] new_tx,
    input  uart_rx,
    output uart_tx,
    output tx_done,
    output tx_busy,
    output [7:0] rx_data,
    output rx_done
);
    wire w_b_tick_9600_16sam;
    wire w_rx_done, w_tx_start, w_tx_done, w_tx_busy;
    wire [7:0] w_tx_data, w_rx_data;

    assign w_tx_data = (set_en_tx)? new_tx : w_rx_data;
    assign w_tx_start = (set_en_tx)? en_tx_start : w_rx_done; 

    assign rx_data = w_rx_data;
    assign rx_done = w_rx_done;
    assign tx_done = w_tx_done;
    assign tx_busy = w_tx_busy;

    uart_rx U_UART_RX (
        .clk        (clk),
        .rst        (rst),
        .rx         (uart_rx),
        .b_tick     (w_b_tick_9600_16sam),
        .rx_data    (w_rx_data),
        .rx_done    (w_rx_done)
    );

    uart_tx U_UART_TX (
        .clk(clk),
        .rst(rst),
        .tx_start(w_tx_start),
        .b_tick(w_b_tick_9600_16sam),
        .tx_data(w_tx_data),
        .uart_tx(uart_tx),
        .tx_busy(w_tx_busy),
        .tx_done(w_tx_done)
    );

    baud_tick_sampling_divide U_BAUD_TICK (
        .clk(clk),
        .rst(rst),
        .b_tick(w_b_tick_9600_16sam)
    );

endmodule

module uart_top_0205 (
    input  clk,
    input  rst,
    input  btn_down,
    output uart_tx
);
    wire w_tx_start, w_b_tick_9600_16sam;

    btn_debounce U_BD_TX_START (
        .clk  (clk),
        .reset(rst),
        .i_btn(btn_down),
        .o_btn(w_tx_start)
    );

    uart_tx U_UART_TX (
        .clk(clk),
        .rst(rst),
        .tx_start(w_tx_start),
        .b_tick(w_b_tick_9600_16sam),
        .tx_data(8'h30),
        .uart_tx(uart_tx),
        .tx_busy(),
        .tx_done()
    );

    baud_tick_sampling_divide U_BAUD_TICK (
        .clk(clk),
        .rst(rst),
        .b_tick(w_b_tick_9600_16sam)
    );

endmodule

module uart_rx (
    input           clk,
    input           rst,
    input           rx,
    input           b_tick,
    output [7:0]    rx_data,
    output          rx_done
);

    // State
    localparam IDLE = 2'd0, START = 2'd1;
    localparam DATA = 2'd2, STOP = 2'd3;

    reg [1:0] c_state, n_state;
    reg [4:0] b_tick_cnt_reg, next_b_tick_cnt;
    reg [2:0] bit_cnt_reg, next_bit_cnt;
    reg rx_done_reg, rx_done_next;
    reg [7:0] buf_reg, next_buf;

    assign rx_data = buf_reg;
    assign rx_done = rx_done_reg;

    // State, Counter REG
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state         <= 2'b00;
            b_tick_cnt_reg  <= 5'b00000;
            bit_cnt_reg     <= 3'b000;
            rx_done_reg     <= 1'b0;
            buf_reg         <= 8'b0000_0000;
        end else begin
            c_state         <= n_state;
            b_tick_cnt_reg  <= next_b_tick_cnt;
            bit_cnt_reg     <= next_bit_cnt;
            rx_done_reg     <= rx_done_next;
            buf_reg         <= next_buf;
        end
    end

    // next, output
    always @(*) begin
        n_state             = c_state;
        next_b_tick_cnt     = b_tick_cnt_reg;
        next_bit_cnt        = bit_cnt_reg;
        rx_done_next        = rx_done_reg;
        next_buf            = buf_reg;
        case(c_state)
            IDLE: begin
                next_b_tick_cnt = 5'b00000;
                next_bit_cnt = 3'b000;
                rx_done_next = 1'b0;
                next_buf = 8'b0000_0000;

                if (b_tick & (rx == 0)) begin
                    n_state = START;
                end
            end
            START: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 7) begin
                        next_b_tick_cnt = 0;
                        //next_bit_cnt = bit_cnt_reg + 1;
                        n_state = DATA;
                    end else begin
                        next_b_tick_cnt = b_tick_cnt_reg + 1;
                    end
                end
            end
            DATA: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        next_b_tick_cnt = 0;
                        next_buf = {rx, buf_reg[7:1]};

                        if (bit_cnt_reg == 7) begin
                            n_state = STOP;
                        end else begin
                            next_bit_cnt = bit_cnt_reg + 1;
                        end 
                    end else begin
                        next_b_tick_cnt = b_tick_cnt_reg + 1;
                    end
                end
            end
            STOP: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        next_b_tick_cnt = 0;
                        rx_done_next = 1'b1;
                        n_state = IDLE;
                    end else begin
                        next_b_tick_cnt = b_tick_cnt_reg + 1;
                    end
                end
            end
        endcase
    end

endmodule

// USE PISO (PARALLEL INPUT SERIAL OUTPUT)
module uart_tx (
    input clk,
    input rst,
    input tx_start,
    input b_tick,  // *16
    input [7:0] tx_data,
    output tx_busy,
    output tx_done,
    output uart_tx
);

    // State
    localparam IDLE = 2'd0, START = 2'd1;
    localparam DATA = 2'd2, STOP = 2'd3;

    // state, counter reg
    reg [1:0] c_state, n_state;
    reg tx_reg, tx_next;
    reg [3:0] b_tick_cnt_reg, next_b_tick_cnt;
    reg [2:0] bit_cnt_reg, next_bit_cnt;
    // busy, done
    reg busy_reg, busy_next, done_reg, done_next;
    // data_in_buf
    reg [7:0] data_in_buf_reg, data_in_buf_next;

    assign uart_tx = tx_reg;
    assign tx_busy = busy_reg;
    assign tx_done = done_reg;

    // SL
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state <= IDLE;
            tx_reg <= 1'b1;
            b_tick_cnt_reg <= 4'b0000;
            bit_cnt_reg <= 1'b0;
            busy_reg <= 1'b0;
            done_reg <= 1'b0;
            data_in_buf_reg <= 8'h00;
        end else begin
            c_state <= n_state;
            tx_reg <= tx_next;
            b_tick_cnt_reg <= next_b_tick_cnt;
            bit_cnt_reg <= next_bit_cnt;
            busy_reg <= busy_next;
            done_reg <= done_next;
            data_in_buf_reg <= data_in_buf_next;
        end
    end

    // next CL
    always @(*) begin
        n_state = c_state;

        tx_next = tx_reg;

        next_b_tick_cnt = b_tick_cnt_reg;
        next_bit_cnt = bit_cnt_reg;

        busy_next = busy_reg;
        done_next = done_reg;

        data_in_buf_next = data_in_buf_reg;
        case (c_state)
            IDLE: begin
                tx_next = 1'b1;

                next_bit_cnt = 0;
                next_b_tick_cnt = 0;

                busy_next = 1'b0;
                done_next = 1'b0;
                if (tx_start) begin
                    n_state = START;
                    busy_next = 1'b1;
                    data_in_buf_next = tx_data;
                end
            end
            START: begin
                // TO START UART FRAME OF START BIT
                tx_next = 1'b0;

                if (b_tick) begin
                    next_b_tick_cnt = b_tick_cnt_reg + 1;
                    if (b_tick_cnt_reg == 4'd15) begin
                        n_state = DATA;
                    end
                end
            end
            DATA: begin
                tx_next = data_in_buf_reg[0];

                if (b_tick) begin
                    next_b_tick_cnt = b_tick_cnt_reg + 1;

                    if (b_tick_cnt_reg == 15) begin
                        data_in_buf_next = {1'b0, data_in_buf_reg[7:1]};
                        next_bit_cnt = bit_cnt_reg + 1;
                        next_b_tick_cnt = 4'h0;

                        if (bit_cnt_reg == 7) begin
                            n_state = STOP;
                        end
                    end
                end
            end
            STOP: begin
                tx_next = 1'b1;

                if (b_tick) begin
                    next_b_tick_cnt = b_tick_cnt_reg + 1;
                    if (b_tick_cnt_reg == 15) begin
                        n_state   = IDLE;
                        busy_next = 1'b0;
                        done_next = 1'b1;
                    end
                end
            end
        endcase
    end

endmodule

module uart_tx_0205 (
    input clk,
    input rst,
    input tx_start,
    input b_tick,  // *16
    input [7:0] tx_data,
    output tx_busy,
    output tx_done,
    output uart_tx
);

    // State
    localparam IDLE = 3'd0, WAIT = 3'd1, START = 3'd2;
    localparam DATA = 3'd3, STOP = 3'd4;

    // state, counter reg
    reg [2:0] c_state, n_state;
    reg tx_reg, tx_next;
    reg [3:0] b_tick_cnt_reg, next_b_tick_cnt;
    reg [2:0] bit_cnt_reg, next_bit_cnt;
    // busy, done
    reg busy_reg, busy_next, done_reg, done_next;
    // data_in_vuf
    reg [7:0] data_in_buf_reg, data_in_buf_next;

    assign uart_tx = tx_reg;
    assign tx_busy = busy_reg;
    assign tx_done = done_reg;

    // SL
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state <= IDLE;
            tx_reg <= 1'b1;
            b_tick_cnt_reg <= 4'b0000;
            bit_cnt_reg <= 1'b0;
            busy_reg <= 1'b0;
            done_reg <= 1'b0;
            data_in_buf_reg <= 8'h00;
        end else begin
            c_state <= n_state;
            tx_reg <= tx_next;
            b_tick_cnt_reg <= next_b_tick_cnt;
            bit_cnt_reg <= next_bit_cnt;
            busy_reg <= busy_next;
            done_reg <= done_next;
            data_in_buf_reg <= data_in_buf_next;
        end
    end

    // next CL
    always @(*) begin
        n_state = c_state;

        tx_next = tx_reg;

        next_b_tick_cnt = b_tick_cnt_reg;
        next_bit_cnt = bit_cnt_reg;

        busy_next = busy_reg;
        done_next = done_reg;

        data_in_buf_next = data_in_buf_reg;
        case (c_state)
            IDLE: begin
                tx_next = 1'b1;

                next_bit_cnt = 0;
                next_b_tick_cnt = 0;

                busy_next = 1'b0;
                done_next = 1'b0;
                if (tx_start) begin
                    n_state = WAIT;
                    busy_next = 1'b1;
                    data_in_buf_next = tx_data;
                end
            end
            WAIT: begin
                if (b_tick) begin
                    n_state = START;
                end
            end
            START: begin
                // TO START UART FRAME OF START BIT
                tx_next = 1'b0;

                if (b_tick) begin
                    next_b_tick_cnt = b_tick_cnt_reg + 1;
                    if (b_tick_cnt_reg == 4'd15) begin
                        n_state = DATA;
                    end
                end

                /* for trouble shooting
                if (b_tick_cnt_reg == 4'b0000) begin
                    if (b_tick) begin
                        tx_next = 1'b0;
                    end
                end
                if (b_tick_cnt_reg == 4'b1111) begin
                    if (b_tick) begin
                        n_state = DATA;
                    end
                end
                */
            end
            DATA: begin
                tx_next = data_in_buf_reg[bit_cnt_reg];

                if (b_tick) begin
                    next_b_tick_cnt = b_tick_cnt_reg + 1;
                    if (b_tick_cnt_reg == 15) begin
                        next_bit_cnt = bit_cnt_reg + 1;
                        next_b_tick_cnt = 0;

                        if (bit_cnt_reg == 7) begin
                            n_state = STOP;
                        end
                    end
                end
            end
            STOP: begin
                tx_next = 1'b1;

                if (b_tick) begin
                    next_b_tick_cnt = b_tick_cnt_reg + 1;
                    if (b_tick_cnt_reg == 15) begin
                        n_state   = IDLE;
                        done_next = 1'b1;
                    end
                end
            end
        endcase
    end

endmodule

module uart_tx_lecture (
    input clk,
    input rst,
    input tx_start,
    input b_tick,  // *16
    input [7:0] tx_data,
    output tx_busy,
    output tx_done,
    output uart_tx
);

    // State
    localparam IDLE = 3'd0, WAIT = 3'd1, START = 3'd2;
    localparam DATA = 3'd3, STOP = 3'd4;

    // state, counter reg
    reg [2:0] c_state, n_state;
    reg tx_reg, tx_next;
    reg [2:0] bit_cnt_reg, next_bit_cnt;
    // busy, done
    reg busy_reg, busy_next, done_reg, done_next;
    // data_in_vuf
    reg [7:0] data_in_buf_reg, data_in_buf_next;

    assign uart_tx = tx_reg;
    assign tx_busy = busy_reg;
    assign tx_done = done_reg;

    // SL
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state <= IDLE;
            tx_reg <= 1'b1;
            bit_cnt_reg <= 1'b0;
            busy_reg <= 1'b0;
            done_reg <= 1'b0;
            data_in_buf_reg <= 8'h00;
        end else begin
            c_state <= n_state;
            tx_reg <= tx_next;
            bit_cnt_reg <= next_bit_cnt;
            busy_reg <= busy_next;
            done_reg <= done_next;
            data_in_buf_reg <= data_in_buf_next;
        end
    end

    // next CL
    always @(*) begin
        n_state = c_state;
        tx_next = tx_reg;
        next_bit_cnt = bit_cnt_reg;
        busy_next = busy_reg;
        done_next = done_reg;
        data_in_buf_next = data_in_buf_reg;
        case (c_state)
            IDLE: begin
                tx_next = 1'b1;
                next_bit_cnt = 0;
                busy_next = 1'b0;
                done_next = 1'b0;
                if (tx_start) begin
                    busy_next = 1'b1;
                    n_state = WAIT;
                    data_in_buf_next = tx_data;
                end
            end
            WAIT: begin
                if (b_tick) n_state = START;
            end
            START: begin
                // TO START UART FRAME OF START BIT
                tx_next = 1'b0;
                if (b_tick) n_state = DATA;
            end
            DATA: begin
                tx_next = data_in_buf_reg[bit_cnt_reg];
                if (b_tick) begin
                    if (bit_cnt_reg == 7) begin
                        n_state = STOP;
                    end else begin
                        next_bit_cnt = bit_cnt_reg + 1;
                        n_state = DATA;
                    end
                end
            end
            STOP: begin
                tx_next = 1'b1;
                if (b_tick) begin
                    done_next = 1'b1;
                    n_state   = IDLE;
                end
            end
        endcase
    end

endmodule

module uart_tx_v0 (
    input clk,
    input rst,
    input tx_start,
    input b_tick,
    input [7:0] tx_data,
    output uart_tx
);

    // State
    localparam IDLE = 4'd0, WAIT = 4'd1, START = 4'd2;
    localparam BIT0 = 4'd3, BIT1 = 4'd4, BIT2 = 4'd5;
    localparam BIT3 = 4'd6, BIT4 = 4'd7, BIT5 = 4'd8;
    localparam BIT6 = 4'd9, BIT7 = 4'd10, STOP = 4'd11;

    // state reg
    reg [3:0] c_state, n_state;
    reg tx_reg, tx_next;

    assign uart_tx = tx_reg;

    // state register SL
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state <= IDLE;
            tx_reg  <= 1'b1;
        end else begin
            c_state <= n_state;
            tx_reg  <= tx_next;
        end
    end

    // next CL
    always @(*) begin
        n_state = c_state;
        tx_next = tx_reg;
        case (c_state)
            IDLE: begin
                tx_next = 1'b1;
                if (tx_start) n_state = WAIT;
            end
            WAIT: begin
                if (b_tick) n_state = START;
            end
            START: begin
                // TO START UART FRAME OF START BIT
                tx_next = 1'b0;
                if (b_tick) n_state = BIT0;
            end
            BIT0: begin
                tx_next = tx_data[0];
                if (b_tick) n_state = BIT1;
            end
            BIT1: begin
                tx_next = tx_data[1];
                if (b_tick) n_state = BIT2;
            end
            BIT2: begin
                tx_next = tx_data[2];
                if (b_tick) n_state = BIT3;
            end
            BIT3: begin
                tx_next = tx_data[3];
                if (b_tick) n_state = BIT4;
            end
            BIT4: begin
                tx_next = tx_data[4];
                if (b_tick) n_state = BIT5;
            end
            BIT5: begin
                tx_next = tx_data[5];
                if (b_tick) n_state = BIT6;
            end
            BIT6: begin
                tx_next = tx_data[6];
                if (b_tick) n_state = BIT7;
            end
            BIT7: begin
                tx_next = tx_data[7];
                if (b_tick) n_state = STOP;
            end
            STOP: begin
                tx_next = 1'b1;
                if (b_tick) n_state = IDLE;
            end
        endcase
    end

endmodule

module baud_tick_sampling_divide_3types (
    input clk,
    input rst,
    input [1:0] i_baud_rate,
    output reg b_tick
);
    parameter BAUDRATE0 = 9600;
    parameter BAUDRATE1 = 19200;
    parameter BAUDRATE2 = 115200;
    parameter SAMPLING = 16;
    parameter F_COUNT0 = 100_000_000 / (BAUDRATE0 * SAMPLING);
    parameter F_COUNT1 = 100_000_000 / (BAUDRATE1 * SAMPLING);
    parameter F_COUNT2 = 100_000_000 / (BAUDRATE2 * SAMPLING);

    // reg for counter
    reg [$clog2(F_COUNT0)-1:0] counter_reg;

    reg [$clog2(F_COUNT0)-1:0] counter_target;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
        end else begin
            counter_reg <= counter_reg + 1;
            if (counter_reg == counter_target) begin
                b_tick = 1'b1;
                counter_reg <= 0;
            end else begin
                b_tick = 1'b0;
            end
        end
    end

    always @(*) begin
        case(i_baud_rate)
            2'b00: counter_target = F_COUNT0-1;
            2'b01: counter_target = F_COUNT1-1;
            2'b10: counter_target = F_COUNT2-1;
            2'b11: counter_target = 0;
        endcase
    end

endmodule

module baud_tick_sampling_divide (
    input clk,
    input rst,
    output reg b_tick
);
    parameter BAUDRATE = 9600;
    parameter SAMPLING = 16;
    parameter F_COUNT = 100_000_000 / (BAUDRATE * SAMPLING);

    // reg for counter
    reg [$clog2(F_COUNT)-1:0] counter_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
        end else begin
            counter_reg <= counter_reg + 1;
            if (counter_reg == (F_COUNT - 1)) begin
                b_tick = 1'b1;
                counter_reg <= 0;
            end else begin
                b_tick = 1'b0;
            end
        end
    end
endmodule

// teacher's baud_tick
module baud_tick (
    input clk,
    input rst,
    output reg b_tick
);
    parameter BAUDRATE = 9600;
    parameter F_COUNT = 100_000_000 / BAUDRATE;

    // reg for counter
    reg [$clog2(F_COUNT)-1:0] counter_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
        end else begin
            counter_reg <= counter_reg + 1;
            if (counter_reg == (F_COUNT - 1)) begin
                b_tick = 1'b1;
                counter_reg <= 0;
            end else begin
                b_tick = 1'b0;
            end
        end
    end
endmodule

// my
module baud_tick_my #(
    parameter CLOCK_CYCLE_1SEC = 100_000_000,
    parameter TARGET_BAUD = 9600,
    parameter SAMPLES = 16
) (
    input clk,
    input rst,
    output reg b_tick
);
    localparam TICK_CYCLES = CLOCK_CYCLE_1SEC / (TARGET_BAUD * SAMPLES);
    localparam TICK_CNT_WIDTH = $clog2(TICK_CYCLES);

    // Counter Register
    reg [TICK_CNT_WIDTH-1:0] cnt, cnt_next;  // Feed-Back

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            cnt <= 0;
        end else begin
            cnt <= cnt_next;
        end
    end

    always @(*) begin
        b_tick   = 0;
        cnt_next = cnt + 1;
        if (cnt == (TICK_CYCLES - 1)) begin
            b_tick   = 1;
            cnt_next = 0;
        end
    end

endmodule
