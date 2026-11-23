`timescale 1ns/1ps

module tb_top;
  // 1: 35 lệnh (23 lệnh cơ bản + 12 lệnh mở rộng)
  // 0: chỉ kiểm tra chương trình 23 lệnh đầu.
  localparam bit RUN_EXTENDED_TESTS = 1'b1;

  logic clk;
  logic reset;
  logic [31:0] WriteData, DataAdr;
  logic MemWrite;

  int cycle  = 0;
  int errors = 0;
  bit base_pass = 1'b0;
  bit ext_pass  = 1'b0;
  bit finished  = 1'b0;

  top dut (
    .clk(clk),
    .reset(reset),
    .WriteData(WriteData),
    .DataAdr(DataAdr),
    .MemWrite(MemWrite)
  );
	// Tín hiệu quan sát nhanh ngay ở cấp top của testbench
  logic [31:0] dbg_PC, dbg_Instr;
  logic [3:0]  dbg_Flags;

  logic [31:0] dbg_R0, dbg_R2, dbg_R3, dbg_R4, dbg_R5,dbg_R6, dbg_R7, dbg_R8, dbg_R9, dbg_R10, dbg_R11, dbg_R12, dbg_R15;
  logic [31:0] dbg_Mem96, dbg_Mem100, dbg_Mem104;

  assign dbg_PC     = dut.PC;
  assign dbg_Instr  = dut.Instr;
  assign dbg_Flags  = dut.arm_i.c.cl.Flags;
  assign dbg_R0     = dut.arm_i.dp.rf.rf[0];
  assign dbg_R2     = dut.arm_i.dp.rf.rf[2];
  assign dbg_R3     = dut.arm_i.dp.rf.rf[3];
  assign dbg_R4     = dut.arm_i.dp.rf.rf[4];
  assign dbg_R5     = dut.arm_i.dp.rf.rf[5];
  assign dbg_R6     = dut.arm_i.dp.rf.rf[6];
  assign dbg_R7     = dut.arm_i.dp.rf.rf[7];
  assign dbg_R8     = dut.arm_i.dp.rf.rf[8];
  assign dbg_R9     = dut.arm_i.dp.rf.rf[9];
  assign dbg_R10    = dut.arm_i.dp.rf.rf[10];
  assign dbg_R11    = dut.arm_i.dp.rf.rf[11];
  assign dbg_R12    = dut.arm_i.dp.rf.rf[12];
  assign dbg_R15	  = dut.PC + 32'd8;
  
  assign dbg_Mem96  = dut.dmem_i.RAM[24];
  assign dbg_Mem100 = dut.dmem_i.RAM[25];
  assign dbg_Mem104 = dut.dmem_i.RAM[26];
  // Clock chu kỳ 10 ns.
  initial clk = 1'b0;
  always #5 clk = ~clk;

  // Reset được nhả tại 7 ns, trước cạnh lên 15 ns đầu tiên.
  initial begin
    reset = 1'b1;
    #7 reset = 1'b0;
  end

  task automatic check_eq(
    input string name,
    input logic [31:0] actual,
    input logic [31:0] expected
  );
    if (actual !== expected) begin
      $error("[FAIL] %s = 0x%08h (expected 0x%08h)",
             name, actual, expected);
      errors++;
    end else begin
      $display("[PASS] %-18s = 0x%08h (%0d)",
               name, actual, $signed(actual));
    end
  endtask

  // Kiểm tra reset bất đồng bộ ngay khi reset đang được giữ ở mức cao.
  // Data Memory không kiểm tra giá trị ban đầu vì RAM không được reset.
  initial begin
    #1;
    check_eq("Reset PC", dut.PC, 32'h0000_0000);
    check_eq("Reset Flags", {28'b0, dut.arm_i.c.cl.Flags}, 32'h0000_0000);
    check_eq("Reset R0", dut.arm_i.dp.rf.rf[0], 32'h0000_0000);
    check_eq("Reset R1", dut.arm_i.dp.rf.rf[1], 32'h0000_0000);
    check_eq("Reset R14", dut.arm_i.dp.rf.rf[14], 32'h0000_0000);
    if (MemWrite !== 1'b0) begin
      $error("[FAIL] MemWrite must be 0 while reset is asserted");
      errors++;
    end
  end

  // Giám sát chu kỳ và tất cả lần ghi Data Memory tại cạnh xuống.
  always @(negedge clk) begin
    if (!reset && !finished) begin
      cycle++;
      $display("Cyc %02d | PC=0x%02h | Instr=0x%08h | Flags=%b | CondEx=%b | WE=%b | Adr=%3d | WD=0x%08h",
               cycle,
               dut.PC[7:0],
               dut.Instr,
               dut.arm_i.c.cl.Flags,
               dut.arm_i.c.cl.CondEx,
               MemWrite,
               DataAdr,
               WriteData);

      if (MemWrite === 1'b1) begin
        case (DataAdr)
          32'd96: begin
            if (WriteData !== 32'd7) begin
              $error("[FAIL] STR Mem[96]: got %0d, expected 7", WriteData);
              errors++;
            end
          end

          32'd100: begin
            if (WriteData === 32'd7) begin
              $display("--> [MILESTONE 1] Base ARM test passed: Mem[100] = 7");
              base_pass = 1'b1;
            end else begin
              $error("[FAIL] STR Mem[100]: got %0d, expected 7", WriteData);
              errors++;
            end
          end

          32'd104: begin
            if (RUN_EXTENDED_TESTS) begin
              if (WriteData === 32'd42) begin
                $display("--> [MILESTONE 2] Extended test passed: Mem[104] = 42");
                ext_pass = 1'b1;
              end else begin
                $error("[FAIL] STR Mem[104]: got %0d, expected 42", WriteData);
                errors++;
              end
            end else begin
              $error("[FAIL] Unexpected write to Mem[104] in base-only test");
              errors++;
            end
          end

          default: begin
            $error("[FAIL] Unexpected RAM write: Adr=%0d, WD=0x%08h",
                   DataAdr, WriteData);
            errors++;
          end
        endcase
      end else if (MemWrite !== 1'b0) begin
        $error("[FAIL] MemWrite is X/Z at cycle %0d", cycle);
        errors++;
      end

      if (cycle >= 60 &&
          !(RUN_EXTENDED_TESTS ? ext_pass : base_pass)) begin
        $error("[FAIL] TIMEOUT: program did not reach expected memory write");
        finished = 1'b1;
        $finish;
      end
    end
  end

  // Phần kiểm tra kết quả cuối được tách khỏi khối giám sát negedge.
  initial begin
    wait (reset == 1'b0);

    if (!RUN_EXTENDED_TESTS) begin
      wait (base_pass);
      @(posedge clk); #1; // STR đã được chốt vào RAM.

      $display("\n========== BASE TEST: 23 INSTRUCTIONS ==========");
      check_eq("R0",       dut.arm_i.dp.rf.rf[0],  32'd0);
      check_eq("R2",       dut.arm_i.dp.rf.rf[2],  32'd7);
      check_eq("R3",       dut.arm_i.dp.rf.rf[3],  32'd12);
      check_eq("R4",       dut.arm_i.dp.rf.rf[4],  32'd7);
      check_eq("R5",       dut.arm_i.dp.rf.rf[5],  32'd11);
      check_eq("R7",       dut.arm_i.dp.rf.rf[7],  32'd7);
      check_eq("R8 (-2)",  dut.arm_i.dp.rf.rf[8],  32'hFFFF_FFFE);
      check_eq("Mem[96]",  dut.dmem_i.RAM[24],     32'd7);
      check_eq("Mem[100]", dut.dmem_i.RAM[25],     32'd7);
      check_eq("Flags",    {28'b0, dut.arm_i.c.cl.Flags}, 32'h0000_0008);
    end else begin
      wait (ext_pass);
      @(posedge clk); #1; // STR Mem[104] được chốt; PC chuyển tới 0x88.
      check_eq("PC at halt", dut.PC, 32'h0000_0088);

      @(posedge clk); #1; // B . phải giữ PC tại 0x88.
      check_eq("PC hold B.", dut.PC, 32'h0000_0088);

      $display("\n========== EXTENDED TEST: 35 INSTRUCTIONS ==========");
      check_eq("R0 (NoWrite)",    dut.arm_i.dp.rf.rf[0],  32'd0);
      check_eq("R2 (ADDNE skip)", dut.arm_i.dp.rf.rf[2],  32'd7);
      check_eq("R3",              dut.arm_i.dp.rf.rf[3],  32'd12);
      check_eq("R4",              dut.arm_i.dp.rf.rf[4],  32'd7);
      check_eq("R5",              dut.arm_i.dp.rf.rf[5],  32'd11);
      check_eq("R6 (LSL #2)",     dut.arm_i.dp.rf.rf[6],  32'd28);
      check_eq("R7",              dut.arm_i.dp.rf.rf[7],  32'd7);
      check_eq("R8 (-2)",         dut.arm_i.dp.rf.rf[8],  32'hFFFF_FFFE);
      check_eq("R9 (LSR+ADDCS)",  dut.arm_i.dp.rf.rf[9],  32'd42);
      check_eq("R10 (ASR #1)",    dut.arm_i.dp.rf.rf[10], 32'hFFFF_FFFF);
      check_eq("R11 (ROR #2)",    dut.arm_i.dp.rf.rf[11], 32'hC000_0001);
      check_eq("R12 (ANDS)",      dut.arm_i.dp.rf.rf[12], 32'hC000_0001);
      check_eq("Flags (NZCV)",    {28'b0, dut.arm_i.c.cl.Flags}, 32'h0000_000A);
      check_eq("Mem[96]",          dut.dmem_i.RAM[24], 32'd7);
      check_eq("Mem[100]",         dut.dmem_i.RAM[25], 32'd7);
      check_eq("Mem[104]",         dut.dmem_i.RAM[26], 32'd42);

      if (!base_pass) begin
        $error("[FAIL] Base milestone Mem[100]=7 was not reached");
        errors++;
      end
    end

    if (errors == 0)
      $display("\n=== ALL SELECTED ARM SINGLE-CYCLE TESTS PASSED (0 ERRORS) ===");
    else
      $display("\n=== SIMULATION FAILED: %0d ERROR(S) ===", errors);

    finished = 1'b1;
    $finish;
  end
endmodule
