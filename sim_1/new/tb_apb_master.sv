`timescale 1ns / 1ps

function bit [31:0] address_create(bit [2:0] dev, bit [11:0] slv_addr);
    typedef enum logic [2:0] {RAM, GPO, GPI, GPIO, FND, UART} slave_type;
    bit [20:0] dev_addr;
    dev_addr = 20'b0000_0000_0000_0000_0000;
    case(dev)
        RAM : dev_addr = 20'b0001_0000_0000_0000_0000;
        GPO : dev_addr = 20'b0010_0000_0000_0000_0000;
        GPI : dev_addr = 20'b0010_0000_0000_0000_0001;
        GPIO: dev_addr = 20'b0010_0000_0000_0000_0010;
        FND : dev_addr = 20'b0010_0000_0000_0000_0011;
        UART: dev_addr = 20'b0010_0000_0000_0000_0100;
    endcase

    return {dev_addr, slv_addr};
endfunction

function bit [5:0] psel_create(bit [2:0] dev);
    typedef enum logic [2:0] {RAM, GPO, GPI, GPIO, FND, UART} slave_type;
    bit [5:0] dev_psel;
    dev_psel = 6'b000000;
    case(dev)
        RAM : dev_psel = 6'b000001;
        GPO : dev_psel = 6'b000010;
        GPI : dev_psel = 6'b000100;
        GPIO: dev_psel = 6'b001000;
        FND : dev_psel = 6'b010000;
        UART: dev_psel = 6'b100000;
    endcase

    return dev_psel;
endfunction

function string dev_name_get(bit [2:0] dev);
    typedef enum logic [2:0] {RAM, GPO, GPI, GPIO, FND, UART} slave_type;
    string dev_name;
    dev_name = "NO USE BUS";
    case(dev)
        RAM : dev_name = "RAM";
        GPO : dev_name = "GPO";
        GPI : dev_name = "GPI";
        GPIO: dev_name = "GPIO";
        FND : dev_name = "FND";
        UART: dev_name = "UART";
    endcase

    return dev_name;
endfunction

interface apb_interface(input pclk);
    logic           preset;
    logic [31:0]    addr;
    logic [31:0]    wdata;
    logic           wreq;
    logic           rreq;
    logic           slverr;
    logic [31:0]    rdata;
    logic           ready;
    logic [31:0]    paddr;
    logic [31:0]    pwdata;
    logic [5:0]     psel;
    logic           penable;
    logic           pwrite;
    logic           pslverr [0:5];
    logic [31:0]    prdata  [0:5];
    logic           pready  [0:5];
endinterface

class trans_inst_gen;
    rand bit [2:0]  target_device;  // Slave 디바이스 선택
    rand bit [11:0] rand_slv_addr;  // Slave 디바이스 내 주소
    rand bit        rand_wreq;      // 쓰기/읽기 요청 선택
    rand bit [31:0] rand_wdata;     // 쓰기용 랜덤 데이터 결정 
    rand bit [2:0]  rand_wait;      // 대기 사이클 결정
    rand bit        rand_error_slv; 
    rand bit [31:0] rand_rdata;     // 읽기용 랜덤 데이터 결정 
    rand bit [23:0] rand_trash_data;// 다른 Slave가 출력하는 데이터 
    rand bit        rand_continuous_transf;

    constraint t_dev { target_device < 6; };
endclass

class generator;
    trans_inst_gen tr_inst;
    mailbox #(trans_inst_gen) gen2drv_mbox;
    mailbox #(trans_inst_gen) gen2scb_mbox;
    event gen_next;

    function new(mailbox #(trans_inst_gen) gen2drv_mbox, mailbox #(trans_inst_gen) gen2scb_mbox,
                 event gen_next);
        this.gen2drv_mbox = gen2drv_mbox;
        this.gen2scb_mbox = gen2scb_mbox;
        this.gen_next = gen_next;
    endfunction

    task run(int test_time);
        repeat(test_time) begin
            tr_inst = new();
            tr_inst.randomize();
            gen2drv_mbox.put(tr_inst);
            gen2scb_mbox.put(tr_inst);
            
            @(gen_next); 
        end
    endtask

endclass

class driver;
    trans_inst_gen tr_inst;
    mailbox #(trans_inst_gen) gen2drv_mbox;

    virtual apb_interface apb_if;

    bit [7:0] slv_target;
    int wait_time;

    function new(mailbox #(trans_inst_gen) gen2drv_mbox, virtual apb_interface apb_if);
        this.gen2drv_mbox = gen2drv_mbox;
        this.apb_if = apb_if;
    endfunction

    task preset();
        apb_if.preset = 1'b1;
        apb_if.addr = 0;
        apb_if.wdata = 0;
        apb_if.wreq = 0;
        apb_if.rreq = 0;
        for (slv_target = 0; slv_target < 6; slv_target++) begin
            apb_if.pslverr[slv_target] = 1'b0;
            apb_if.prdata[slv_target] = 0;
            apb_if.pready[slv_target] = 1'b0;
        end
        @(posedge apb_if.pclk);
        @(posedge apb_if.pclk);
        apb_if.preset = 1'b0;
        @(posedge apb_if.pclk);
        $display(" Reset Done -------------------");

    endtask;

    task impl_valification(virtual apb_interface apb_if, bit [2:0] dev, bit [11:0] slv_addr, bit rw, bit [31:0] data, int wait_in);
        shortint slv_target, wait_time;

        bit [31:0] addr;
        addr = address_create(dev, slv_addr);
        $display("%d, %h", dev, slv_addr);
        apb_if.addr = addr;
        apb_if.wreq = rw; apb_if.rreq = ~rw;
        apb_if.wdata = data;

        for (slv_target = 0; slv_target < 6; slv_target++) begin
            apb_if.pslverr[slv_target] = 1'b0;
            apb_if.prdata[slv_target] = 32'b0;
            apb_if.pready[slv_target] = 1'b0;
        end

        apb_if.pslverr[dev] = 1'b0;
        apb_if.prdata[dev] = data;
        apb_if.pready[dev] = 1'b0;

        while (apb_if.penable == 0) begin
            @(posedge apb_if.pclk); #1;
        end

        for (wait_time = 0; wait_time < wait_in; wait_time++) begin
            @(posedge apb_if.pclk); #1;
        end

        apb_if.pready[dev] = 1'b1;
        @(posedge apb_if.pclk); #1;
        apb_if.wreq = 0; apb_if.rreq = 0;
        apb_if.pready[dev] = 1'b0;
        @(posedge apb_if.pclk); #1;
    endtask

    task run();
        forever begin
            gen2drv_mbox.get(tr_inst);
            if (tr_inst.rand_continuous_transf) begin
                @(posedge apb_if.pclk); #1;
            end 
            apb_if.addr = address_create(tr_inst.target_device, tr_inst.rand_slv_addr);
            apb_if.wreq = tr_inst.rand_wreq; apb_if.rreq = ~tr_inst.rand_wreq;
            apb_if.wdata = tr_inst.rand_wdata;

            for (slv_target = 0; slv_target < 6; slv_target++) begin
                apb_if.pslverr[slv_target] = 1'b0;
                apb_if.prdata[slv_target] = {tr_inst.rand_trash_data, slv_target};
                apb_if.pready[slv_target] = 1'b0;
            end

            apb_if.pslverr[tr_inst.target_device] = tr_inst.rand_error_slv;
            apb_if.prdata[tr_inst.target_device] = tr_inst.rand_rdata;
            apb_if.pready[tr_inst.target_device] = 1'b0;

            while (apb_if.penable == 0) begin
                @(posedge apb_if.pclk); #1;
            end

            for (wait_time = 0; wait_time < tr_inst.rand_wait; wait_time++) begin
                @(posedge apb_if.pclk); #1;
            end

            apb_if.pready[tr_inst.target_device] = 1'b1;
            @(posedge apb_if.pclk); #1;
            apb_if.wreq = 0; apb_if.rreq = 0;
            apb_if.pready[tr_inst.target_device] = 1'b0;
            @(posedge apb_if.pclk); #1;
        end
    endtask

endclass

class trans_mon2scb;
    logic           slverr;
    logic [31:0]    rdata;
    logic           ready;
    logic [31:0]    paddr;
    logic [31:0]    pwdata;
    logic [5:0]     psel;
    logic           penable [0:8];
    logic           pwrite;
    bit   [2:0]     wait_time;
endclass

class monitor;
    trans_mon2scb tr_signals;
    mailbox #(trans_mon2scb) mon2scb_mbox;

    virtual apb_interface apb_if;
    
    function new(mailbox #(trans_mon2scb) mon2scb_mbox, virtual apb_interface apb_if);
        this.mon2scb_mbox = mon2scb_mbox;
        this.apb_if = apb_if;
    endfunction

    task run();
        forever begin
            tr_signals = new();
            while (apb_if.penable == 0) begin
                @(negedge apb_if.pclk);
            end

            tr_signals.paddr = apb_if.paddr;
            tr_signals.psel = apb_if.psel;
            tr_signals.penable[8] = apb_if.penable; // First en
            
            if (apb_if.wreq) begin
                tr_signals.pwdata = apb_if.pwdata;
                tr_signals.pwrite = apb_if.pwrite;
            end

            tr_signals.wait_time = 0;
            while (apb_if.ready == 0) begin 
                tr_signals.wait_time++; @(negedge apb_if.pclk); 
            end

            tr_signals.slverr = apb_if.slverr;
            tr_signals.rdata = apb_if.rdata;
            tr_signals.ready = apb_if.ready;
            mon2scb_mbox.put(tr_signals);
            @(negedge apb_if.pclk);
        end
    endtask

endclass

class scoreboard;
    trans_inst_gen tr_inst;
    trans_mon2scb tr_signals;
    mailbox #(trans_inst_gen) gen2scb_mbox;
    mailbox #(trans_mon2scb) mon2scb_mbox;

    event gen_next;

    int try_cnt;
    int pass_cnt;
    int fail_cnt;
    
    bit fail_exist;

    bit [5:0] expect_psel;
    bit [31:0] expect_paddr;
    string dev_name;

    function new(mailbox #(trans_inst_gen) gen2scb_mbox, mailbox #(trans_mon2scb) mon2scb_mbox, 
                 event gen_next);
        this.gen2scb_mbox = gen2scb_mbox;
        this.mon2scb_mbox = mon2scb_mbox;
        this.gen_next = gen_next;
         
        try_cnt = 0;
        pass_cnt = 0;
        fail_cnt = 0;
    endfunction
    
    task run();
        forever begin
            gen2scb_mbox.get(tr_inst);
            mon2scb_mbox.get(tr_signals);

            expect_psel = psel_create(tr_inst.target_device);
            dev_name = dev_name_get(tr_inst.target_device);

            try_cnt++; fail_exist = 0;

            $display("================> %d", try_cnt);
            // PSEL
            if (expect_psel != tr_signals.psel) begin
                $display("[FAIL]    PSEL is not match!! TARGET_DEVICE: %s, EXPECT_PSEL: %b, OUT_PSEL: %b", 
                            dev_name, expect_psel, tr_signals.psel);
                fail_exist = 1;
            end
            else begin
                $display("select %s device!", dev_name);
            end

            // PADDR
            expect_paddr = address_create(tr_inst.target_device, tr_inst.rand_slv_addr);
            if (expect_paddr != tr_signals.paddr) begin
                $display("[FAIL]    PADDR is not match!! EXPECT_PADDR: %b, OUT_PADDR: %b", 
                            expect_paddr, tr_signals.pwrite);
                fail_exist = 1;
            end

            // PWRITE
            if (tr_inst.rand_wreq != tr_signals.pwrite) begin
                $display("[FAIL]    PWRITE is not match!! EXPECT_PWRITE: %h, OUT_PWRITE: %h", 
                            tr_inst.rand_wreq, tr_signals.pwrite);
                fail_exist = 1;
            end

            if (tr_inst.rand_wreq) begin
                $display(" WRITE )");

                // PWDATA
                if (tr_inst.rand_wdata != tr_signals.pwdata) begin
                    $display("[FAIL]    PWDATA is not match!! EXPECT_PWDATA: %d, OUT_PWDATA: %d", 
                                tr_inst.rand_wdata, tr_signals.pwdata);
                    fail_exist = 1;
                end

            end
            else begin
                $display(" READ )");
                
                // RDATA
                if (tr_inst.rand_rdata != tr_signals.rdata) begin
                    $display("[FAIL]    RDATA is not match!! EXPECT_RDATA: %h, OUT_PWDATA: %h", 
                                tr_inst.rand_rdata, tr_signals.rdata);
                    fail_exist = 1;
                end

            end

            if (tr_inst.rand_wait != tr_signals.wait_time) begin
                $display("[FAIL]    wait time is not match!! EXPECT wait time: %d, OUT wait time: %d", 
                            tr_inst.rand_wait, tr_signals.wait_time);
                fail_exist = 1;
            end

            $display("%d DONE!", try_cnt);
            if (fail_exist == 0) pass_cnt++;
            else fail_cnt++;

            ->gen_next;
        end
    endtask;

endclass

class environment;
    generator   gen;
    driver      drv;
    monitor     mon;
    scoreboard  scb;

    mailbox #(trans_inst_gen)   gen2drv_mbox;
    mailbox #(trans_inst_gen)   gen2scb_mbox;
    mailbox #(trans_mon2scb)    mon2scb_mbox;
    
    event gen_next;

    virtual apb_interface apb_if;
    
    typedef enum logic [2:0] {RAM, GPO, GPI, GPIO, FND, UART} slave_type;
    typedef enum logic {READ, WRITE} req_type;

    function new(virtual apb_interface apb_if);
        this.apb_if = apb_if;

        gen2drv_mbox = new();
        gen2scb_mbox = new();
        mon2scb_mbox = new();

        gen = new(gen2drv_mbox, gen2scb_mbox, gen_next);
        drv = new(gen2drv_mbox, apb_if);
        mon = new(mon2scb_mbox, apb_if);
        scb = new(gen2scb_mbox, mon2scb_mbox, gen_next);
    endfunction

    task run(int run_times);
        drv.preset();
        
        // IMPLEMENTATION VALIFICATION
            // RAM
        drv.impl_valification(apb_if, RAM, 12'h000, READ, 32'hFFFF_FFFF, 2);
        drv.impl_valification(apb_if, RAM, 12'h004, WRITE, 32'h0000_FFFF, 2);
            // GPO
        drv.impl_valification(apb_if, GPO, 12'h008, READ, 32'hFFFF_0000, 2);
        drv.impl_valification(apb_if, GPO, 12'h00C, WRITE, 32'h00FF_FF00, 2);
            // GPI
        drv.impl_valification(apb_if, GPI, 12'h000, READ, 32'h0000_0000, 2);
        drv.impl_valification(apb_if, GPI, 12'h004, WRITE, 32'h0000_FF00, 2);
            // GPIO
        drv.impl_valification(apb_if, GPIO, 12'h008, READ, 32'h0000_0000, 2);
        drv.impl_valification(apb_if, GPIO, 12'h00C, WRITE, 32'h0000_FF00, 2);
            // FND
        drv.impl_valification(apb_if, FND, 12'h000, READ, 32'h0000_0000, 2);
        drv.impl_valification(apb_if, FND, 12'h004, WRITE, 32'h0000_FF00, 2);
            // UART
        drv.impl_valification(apb_if, UART, 12'h008, READ, 32'h0000_0000, 2);
        drv.impl_valification(apb_if, UART, 12'h00C, WRITE, 32'h0000_FF00, 2);

        $display("===== IMPLEMENTATION VALIFICATION DONE !!! =====");
        $stop;

        fork
            gen.run(run_times);
            drv.run();
            mon.run();
            scb.run();
        join_any

        $display("===== RANDOM REQUEST VALIFICATION RESULT =====");
        $display("  PASS: %d / %d", scb.pass_cnt, scb.try_cnt);
        $display("  FAIL: %d / %d", scb.fail_cnt, scb.try_cnt);
        $display("==============================================");
        $display("Good Bye");
        $stop;
    endtask
endclass
/*
*/
module tb_apb_master();

    logic clk;
    logic a;

    shortint slv_target;
    
    environment env;

    apb_interface apb_if(clk);

    apb_master dut(
        .PCLK       (apb_if.pclk),
        .PRESET     (apb_if.preset),
        .Addr       (apb_if.addr),
        .Wdata      (apb_if.wdata),
        .WREQ       (apb_if.wreq),
        .RREQ       (apb_if.rreq),
        .SlvERR     (apb_if.slverr),
        .Rdata      (apb_if.rdata),
        .Ready      (apb_if.ready),
        .PADDR      (apb_if.paddr),
        .PWDATA     (apb_if.pwdata),
        .PSEL       (apb_if.psel),
        .PENABLE    (apb_if.penable),
        .PWRITE     (apb_if.pwrite),
        .PSlvERR0   (apb_if.pslverr[0]),
        .PRDATA0    (apb_if.prdata[0]),
        .PREADY0    (apb_if.pready[0]),
        .PSlvERR1   (apb_if.pslverr[1]),
        .PRDATA1    (apb_if.prdata[1]),
        .PREADY1    (apb_if.pready[1]),
        .PSlvERR2   (apb_if.pslverr[2]),
        .PRDATA2    (apb_if.prdata[2]),
        .PREADY2    (apb_if.pready[2]),
        .PSlvERR3   (apb_if.pslverr[3]),
        .PRDATA3    (apb_if.prdata[3]),
        .PREADY3    (apb_if.pready[3]),
        .PSlvERR4   (apb_if.pslverr[4]),
        .PRDATA4    (apb_if.prdata[4]),
        .PREADY4    (apb_if.pready[4]),
        .PSlvERR5   (apb_if.pslverr[5]),
        .PRDATA5    (apb_if.prdata[5]),
        .PREADY5    (apb_if.pready[5])
    );

    always #5 begin clk = ~clk; end

    initial begin
        
        clk = 1;
        
        env = new(apb_if);
        env.run(6*4096*128);
    end

endmodule
