`default_nettype none
`timescale 1ns/1ps

module tb;

    reg clk;
    reg rst_n;
    wire halted;
    reg ena;
    reg [7:0] ui_in;
    reg [7:0] uio_in;
    wire [7:0] uo_out;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

    tt_um_cpu_top #(
        .IMEM_DEPTH(10),
        .DMEM_DEPTH(1)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .ena(ena),
        .ui_in  (ui_in),    // Dedicated inputs
        .uo_out (uo_out),   // Dedicated outputs
        .uio_in (uio_in),   // IOs: Input path
        .uio_out(uio_out),  // IOs: Output path
        .uio_oe (uio_oe),   // IOs: Enable path (active high: 0=input, 1=output)
        .ena    (ena),      // enable - goes high when design is selected
        
    );

    // clock: 10 ns period
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // reset
    initial begin
        rst_n = 1'b0;
        #20;
        rst_n = 1'b1;
    end

    // timeout protection
    initial begin
        #2000;
        $display("TIMEOUT: simulation did not halt");
        $finish;
    end

    // basic monitoring
    initial begin
        $display("Starting simulation...");
        $monitor("t=%0t | pc=%h | halted=%b", $time, dut.pc_q, halted);
    end

    // finish on halt
    always @(posedge clk) begin
        if (ou_out[0]) begin
            $display("\nCPU halted.");
            $display("Register x1 = %0d (0x%08h)", dut.u_rf.regs[1], dut.u_rf.regs[1]);
            $display("Register x2 = %0d (0x%08h)", dut.u_rf.regs[2], dut.u_rf.regs[2]);
            $display("Register x3 = %0d (0x%08h)", dut.u_rf.regs[3], dut.u_rf.regs[3]);
            $display("Register x4 = %0d (0x%08h)", dut.u_rf.regs[4], dut.u_rf.regs[4]);
            $display("DMEM[0] = %0d (0x%08h)", dut.u_dmem.mem[0], dut.u_dmem.mem[0]);
            $finish;
        end
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb);
    end

endmodule

// x1 = 5
// x2 = 7
// x3 = 12
// x4 = 12
// DMEM[0] = 12

// 20010005   ADDI x1, x0, 5      -> x1 = 5
// 20020007   ADDI x2, x0, 7      -> x2 = 7
// 00221820   ADD  x3, x1, x2     -> x3 = 12
// AC030000   SW   x3, 0(x0)      -> DMEM[0] = 12
// 8C040000   LW   x4, 0(x0)      -> x4 = 12
// 10640001   BEQ  x3, x4, 1      -> taken, skips next instruction
// 20010063   ADDI x1, x0, 99     -> skipped
// 14220001   BNE  x1, x2, 1      -> taken because 5 != 7
// 20020058   ADDI x2, x0, 88     -> skipped
// FC000000   HALT
