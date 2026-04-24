`default_nettype none
`timescale 1ns/1ps

module tb;

    reg clk;
    reg rst_n;
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
        .ui_in(ui_in),
        .uo_out(uo_out),
        .uio_in(uio_in),
        .uio_out(uio_out),
        .uio_oe(uio_oe)
    );

    // clock
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // reset + inputs
    initial begin
        ena = 1'b1;
        ui_in = 8'b0;
        uio_in = 8'b0;

        rst_n = 1'b0;
        #20;
        rst_n = 1'b1;
    end

    // timeout
    initial begin
        #2000;
        $display("TIMEOUT: simulation did not halt");
        $finish;
    end

    // monitor
    initial begin
        $display("Starting simulation...");
        $monitor("t=%0t | halted=%b | uo_out=%b", $time, uo_out[0], uo_out);
    end

    // finish + debug prints
    always @(posedge clk) begin
        if (uo_out[0]) begin
            $display("\nCPU halted.");

            $display("Register x1 = %0d (0x%08h)", dut.u_cpu.u_rf.regs[1], dut.u_cpu.u_rf.regs[1]);
            $display("Register x2 = %0d (0x%08h)", dut.u_cpu.u_rf.regs[2], dut.u_cpu.u_rf.regs[2]);
            $display("Register x3 = %0d (0x%08h)", dut.u_cpu.u_rf.regs[3], dut.u_cpu.u_rf.regs[3]);
            $display("Register x4 = %0d (0x%08h)", dut.u_cpu.u_rf.regs[4], dut.u_cpu.u_rf.regs[4]);

            $display("DMEM[0] = %0d (0x%08h)", dut.u_cpu.u_dmem.mem[0], dut.u_cpu.u_dmem.mem[0]);

            $finish;
        end
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb);
    end

endmodule

