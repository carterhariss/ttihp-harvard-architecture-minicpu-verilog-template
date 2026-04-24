`default_nettype none
`timescale 1ns/1ps

module tb_cpu;

    reg clk;
    reg rst_n;
    wire halted;

    cpu_top #(
        .IMEM_DEPTH(256),
        .DMEM_DEPTH(256)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .halted(halted)
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
        if (halted) begin
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
        $dumpvars(0, tb_cpu);
    end

endmodule
