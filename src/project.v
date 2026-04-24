/*
 * Copyright (c) 2024 Carter Harris
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module alu #(
    parameter WIDTH = 32
)(
    input  [WIDTH-1:0] a,
    input  [WIDTH-1:0] b,
    input  [2:0]       op,
    output reg [WIDTH-1:0] y,
    output zero
);

    // op encoding
    localparam ALU_ADD = 3'd0;
    localparam ALU_SUB = 3'd1;
    localparam ALU_AND = 3'd2;
    localparam ALU_OR  = 3'd3;

    always @(*) begin
        case (op)
            ALU_ADD: y = a + b;
            ALU_SUB: y = a - b;
            ALU_AND: y = a & b;
            ALU_OR:  y = a | b;
            default: y = {WIDTH{1'b0}};
        endcase
    end

    assign zero = (y == {WIDTH{1'b0}});

endmodule


module decoder(
    input [31:0] inst,

    output [4:0] rs1,
    output [4:0] rs2,
    output [4:0] rd,

    output reg uses_rs1,
    output reg uses_rs2,

    output reg is_imm,
    output [31:0] imm32,

    output reg [2:0] alu_op,
    output reg reg_wen,

    output reg is_lw,
    output reg is_sw,

    output reg is_branch,
    output reg branch_ne, // 0=BEQ, 1=BNE

    output reg is_jump,
    output reg [31:0] jump_target,

    output reg is_halt
);

    wire [5:0] opcode;
    wire [5:0] funct;

    assign opcode = inst[31:26];
    assign rs1    = inst[25:21];
    assign rs2    = inst[20:16];
    assign rd     = inst[15:11];
    assign funct  = inst[5:0];

    // sign-extend imm16
    assign imm32 = {{16{inst[15]}}, inst[15:0]};

    always @(*) begin
        uses_rs1    = 1'b0;
        uses_rs2    = 1'b0;
        is_imm      = 1'b0;
        alu_op      = 3'd0;
        reg_wen     = 1'b0;
        is_lw       = 1'b0;
        is_sw       = 1'b0;
        is_branch   = 1'b0;
        branch_ne   = 1'b0;
        is_jump     = 1'b0;
        jump_target = 32'd0;
        is_halt     = 1'b0;

        case (opcode)
            6'b000000: begin // Register type: use funct.
                uses_rs1 = 1'b1;
                uses_rs2 = 1'b1;
                reg_wen  = 1'b1;

                case (funct)
                    6'h20: alu_op = 3'd0; // ADD
                    6'h22: alu_op = 3'd1; // SUB
                    6'h24: alu_op = 3'd2; // AND
                    6'h25: alu_op = 3'd3; // OR
                    default: begin
                        reg_wen = 1'b0; // treat unknown as NOP
                    end
                endcase
            end

            6'h08: begin // ADDI
                uses_rs1 = 1'b1;
                uses_rs2 = 1'b0;
                is_imm   = 1'b1;
                alu_op   = 3'd0;
                reg_wen  = 1'b1;
            end

            6'h23: begin // LW
                uses_rs1 = 1'b1;
                uses_rs2 = 1'b0;
                is_imm   = 1'b1;
                alu_op   = 3'd0;
                reg_wen  = 1'b1;
                is_lw    = 1'b1;
            end

            6'h2B: begin // SW
                uses_rs1 = 1'b1;
                uses_rs2 = 1'b1;
                is_imm   = 1'b1;
                alu_op   = 3'd0;
                is_sw    = 1'b1;
                reg_wen  = 1'b0;
            end

            6'h04: begin // BEQ
                uses_rs1  = 1'b1;
                uses_rs2  = 1'b1;
                is_branch = 1'b1;
                branch_ne = 1'b0;
            end

            6'h05: begin // BNE
                uses_rs1  = 1'b1;
                uses_rs2  = 1'b1;
                is_branch = 1'b1;
                branch_ne = 1'b1;
            end

            6'h3F: begin // HALT custom
                is_halt = 1'b1;
            end

            default: begin
                // NOP
            end
        endcase
    end

endmodule


module dmem #(
    parameter DEPTH_WORDS = 1024
)(
    input clk,
    input we,
    input [31:0] addr, // byte address
    input [31:0] wdata,
    output [31:0] rdata
);

    reg [31:0] mem [0:DEPTH_WORDS-1];
    wire [9:0] idx; // for 1024 words, index is 10 bits
    integer i;

    initial begin
        // initialize all memory to 0
        for (i = 0; i < DEPTH_WORDS; i = i + 1)
            mem[i] = 32'd0;

        // load test value
        mem[0] = 32'd6;
    end

    assign idx = addr[11:2]; // word-aligned memory index
    assign rdata = mem[idx]; // combinational read

    always @(posedge clk) begin
        if (we)
            mem[idx] <= wdata;
    end

endmodule

module ex_wb_reg(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        flush,

    input  wire        in_valid,
    input  wire        in_wen,
    input  wire [4:0]  in_rd,
    input  wire [31:0] in_wdata,
    input  wire        in_halt,

    output reg         out_valid,
    output reg         out_wen,
    output reg [4:0]   out_rd,
    output reg [31:0]  out_wdata,
    output reg         out_halt
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid <= 1'b0;
            out_wen   <= 1'b0;
            out_rd    <= 5'd0;
            out_wdata <= 32'd0;
            out_halt  <= 1'b0;
        end
        else if (flush) begin
            out_valid <= 1'b0;
            out_wen   <= 1'b0;
            out_rd    <= 5'd0;
            out_wdata <= 32'd0;
            out_halt  <= 1'b0;
        end
        else begin
            out_valid <= in_valid;
            out_wen   <= in_wen;
            out_rd    <= in_rd;
            out_wdata <= in_wdata;
            out_halt  <= in_halt;
        end
    end

endmodule


module hazard_unit(
    input  wire        if_id_valid,
    input  wire [4:0]  if_rs1,
    input  wire [4:0]  if_rs2,
    input  wire        if_uses_rs1,
    input  wire        if_uses_rs2,

    input  wire        ex_is_lw,
    input  wire [4:0]  ex_rd,

    input  wire        wb_valid,
    input  wire        wb_wen,
    input  wire [4:0]  wb_rd,

    output reg         stall_if,
    output reg         bubble_ex,
    output reg         fwdA,
    output reg         fwdB
);

    always @(*) begin
        stall_if  = 1'b0;
        bubble_ex = 1'b0;

        if (if_id_valid && ex_is_lw && (ex_rd != 5'd0)) begin
            if ((if_uses_rs1 && (if_rs1 == ex_rd)) ||
                (if_uses_rs2 && (if_rs2 == ex_rd))) begin
                stall_if  = 1'b1;
                bubble_ex = 1'b1;
            end
        end
    end

    always @(*) begin
        fwdA = 1'b0;
        fwdB = 1'b0;

        if (wb_valid && wb_wen && (wb_rd != 5'd0) && (wb_rd == if_rs1))
            fwdA = 1'b1;

        if (wb_valid && wb_wen && (wb_rd != 5'd0) && (wb_rd == if_rs2))
            fwdB = 1'b1;
    end

endmodule



module if_id_reg(
    input clk,
    input rst_n,
    input stall,
    input flush,

    input [31:0] in_pc,
    input [31:0] in_inst,
    input in_valid,

    output reg [31:0] out_pc,
    output reg [31:0] out_inst,
    output reg out_valid
);

    localparam [31:0] NOP = 32'h0000_0000;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_pc    <= 32'd0;
            out_inst  <= NOP;
            out_valid <= 1'b0;
        end
        else if (flush) begin
            out_pc    <= 32'd0;
            out_inst  <= NOP;
            out_valid <= 1'b0;
        end
        else if (!stall) begin
            out_pc    <= in_pc;
            out_inst  <= in_inst;
            out_valid <= in_valid;
        end
    end

endmodule
module imem(
    input  [31:0] addr,
    output reg [31:0] inst
);

    always @(*) begin
        case (addr[5:2])
            30'd0: inst = 32'h20010005;
            30'd1: inst = 32'h20020007;
            30'd2: inst = 32'h00221820;
            30'd3: inst = 32'hAC030000;
            30'd4: inst = 32'h8C040000;
            30'd5: inst = 32'h10640001;
            30'd6: inst = 32'h20010063;
            30'd7: inst = 32'h14220001;
            30'd8: inst = 32'h20020058;
            30'd9: inst = 32'hFC000000;
            default: inst = 32'h00000000;
        endcase
    end

endmodule
module regfile #(
    parameter WIDTH = 32,
    parameter NREGS = 32
)(
    input clk,
    // write port
    input wen,
    input [4:0] waddr,
    input [WIDTH-1:0] wdata,
    // read ports
    input [4:0] raddr1,
    input [4:0] raddr2,
    output reg [WIDTH-1:0] rdata1,
    output reg [WIDTH-1:0] rdata2
);

    reg [WIDTH-1:0] regs [0:NREGS-1];
    integer i;

    initial begin
        for (i = 0; i < NREGS; i = i + 1)
            regs[i] = {WIDTH{1'b0}};
    end

    // combinational reads, with x0 = 0
    always @(*) begin
        if (raddr1 == 5'd0)
            rdata1 = {WIDTH{1'b0}};
        else
            rdata1 = regs[raddr1];

        if (raddr2 == 5'd0)
            rdata2 = {WIDTH{1'b0}};
        else
            rdata2 = regs[raddr2];
    end

    // synchronous write, ignore writes to x0
    always @(posedge clk) begin
        if (wen && (waddr != 5'd0)) begin
            regs[waddr] <= wdata;
        end
    end

endmodule

module tt_um_cpu_top #(
    parameter IMEM_DEPTH = 10,
    parameter DMEM_DEPTH = 1
)(
    input clk,
    input rst_n,
    input ena,
    input[7:0] ui_in,
    input[7:0] uio_in,
    output[7:0] uo_out,
    output[7:0] uio_out
    output[7:0] uio_oe;
    output halted
    
);
    if (ena) begin
    // ================= IF STAGE =================
        reg [31:0] pc_q;
        reg [31:0] pc_d;
        wire [31:0] if_inst;
        wire stall_if, flush_if;
        wire branch_taken;
        wire [31:0] branch_target;
        wire clk;
        
        
        wire rst_n;
        wire ena;
       
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n)
                pc_q <= 32'd0;
            else if (!stall_if)
                pc_q <= pc_d;
        end
    
        always @(*) begin
            if (branch_taken)
                pc_d = branch_target;
            else
                pc_d = pc_q + 32'd4;
        end
    
        imem u_imem(
            .addr(pc_q),
            .inst(if_inst)
        );
    
    // ================= IF/ID =================
        wire [31:0] if_id_pc, if_id_inst;
        wire if_id_valid;
    
        if_id_reg u_if_id(
            .clk(clk),
            .rst_n(rst_n),
            .stall(stall_if),
            .flush(flush_if),
            .in_pc(pc_q),
            .in_inst(if_inst),
            .in_valid(1'b1),
            .out_pc(if_id_pc),
            .out_inst(if_id_inst),
            .out_valid(if_id_valid)
        );
    
    // ================= DECODE =================
        wire [4:0] rs1, rs2, rd_rtype;
        wire uses_rs1, uses_rs2;
        wire is_imm;
        wire [31:0] imm32;
        wire [2:0] alu_op;
        wire reg_wen_dec;
        wire is_lw, is_sw;
        wire is_branch, branch_ne;
        wire is_jump;
        wire [31:0] jump_target;
        wire is_halt;
    
        decoder u_dec (
            .inst(if_id_inst),
            .rs1(rs1), .rs2(rs2), .rd(rd_rtype),
            .uses_rs1(uses_rs1), .uses_rs2(uses_rs2),
            .is_imm(is_imm), .imm32(imm32),
            .alu_op(alu_op),
            .reg_wen(reg_wen_dec),
            .is_lw(is_lw),
            .is_sw(is_sw),
            .is_branch(is_branch), .branch_ne(branch_ne),
            .is_jump(is_jump), .jump_target(jump_target),
            .is_halt(is_halt)
        );
    
    // ================= REGFILE =================
        wire rf_wen;
        wire [4:0] rf_waddr;
        wire [31:0] rf_wdata;
        wire [31:0] rf_rdata1, rf_rdata2;
    
        regfile u_rf(
            .clk(clk),
            .wen(rf_wen),
            .waddr(rf_waddr),
            .wdata(rf_wdata),
            .raddr1(rs1),
            .raddr2(rs2),
            .rdata1(rf_rdata1),
            .rdata2(rf_rdata2)
        );
    
    // ================= HAZARD =================
        wire wb_valid, wb_wen;
        wire [4:0] wb_rd;
        wire [31:0] wb_wdata;
        wire wb_halt;
    
        wire bubble_ex, fwdA, fwdB;
    
        hazard_unit u_haz (
            .if_id_valid(if_id_valid),
            .if_rs1(rs1),
            .if_rs2(rs2),
            .if_uses_rs1(uses_rs1),
            .if_uses_rs2(uses_rs2),
            .ex_is_lw(is_lw && if_id_valid),
            .ex_rd((if_id_inst[31:26]==6'b000000) ? rd_rtype : if_id_inst[20:16]),
            .wb_valid(wb_valid),
            .wb_wen(wb_wen),
            .wb_rd(wb_rd),
            .stall_if(stall_if),
            .bubble_ex(bubble_ex),
            .fwdA(fwdA),
            .fwdB(fwdB)
        );
    
    // ================= OPERANDS =================
        wire [31:0] opA_raw, opB_raw;
        wire [31:0] opA, opB, regB;
    
        assign opA_raw = rf_rdata1;
        assign opB_raw = rf_rdata2;
    
        assign opA = fwdA ? wb_wdata : opA_raw;
        assign regB = fwdB ? wb_wdata : opB_raw;
        assign opB = is_imm ? imm32 : regB;
    
    // ================= ALU =================
        wire [31:0] alu_y;
        wire alu_zero;
    
        alu u_alu(
            .a(opA),
            .b(opB),
            .op(alu_op),
            .y(alu_y),
            .zero(alu_zero)
        );
    
    // ================= DMEM =================
        wire [31:0] dmem_rdata;
    
        dmem #(.DEPTH_WORDS(DMEM_DEPTH)) u_dmem (
            .clk(clk),
            .we(if_id_valid && is_sw && !bubble_ex),
            .addr(alu_y),
            .wdata(regB),
            .rdata(dmem_rdata)
        );
    
    // ================= BRANCH =================
        reg take_branch;
    
        always @(*) begin
            take_branch = 1'b0;
            if (if_id_valid && is_branch && !bubble_ex) begin
                if (!branch_ne)
                    take_branch = (regB == opA);
                else
                    take_branch = (regB != opA);
            end
        end
    
        assign branch_taken  = take_branch;
        assign branch_target = if_id_pc + 32'd4 + (imm32 << 2);
        assign flush_if      = branch_taken;
    
    // ================= WB =================
        wire [31:0] ex_result;
        assign ex_result = is_lw ? dmem_rdata : alu_y;
    
        wire [4:0] ex_rd;
        assign ex_rd = (if_id_inst[31:26]==6'b000000) ? rd_rtype : if_id_inst[20:16];
    
        wire ex_valid;
        assign ex_valid = if_id_valid && !bubble_ex;
    
        ex_wb_reg u_ex_wb(
            .clk(clk),
            .rst_n(rst_n),
            .flush(1'b0),
            .in_valid(ex_valid),
            .in_wen(ex_valid && reg_wen_dec),
            .in_rd(ex_rd),
            .in_wdata(ex_result),
            .in_halt(ex_valid && is_halt),
            .out_valid(wb_valid),
            .out_wen(wb_wen),
            .out_rd(wb_rd),
            .out_wdata(wb_wdata),
            .out_halt(wb_halt)
        );
    
    // ================= FINAL =================
        assign rf_wen   = wb_valid && wb_wen && (wb_rd != 5'd0);
        assign rf_waddr = wb_rd;
        assign rf_wdata = wb_wdata;
        assign halted   = wb_valid && wb_halt;
    end

endmodule
