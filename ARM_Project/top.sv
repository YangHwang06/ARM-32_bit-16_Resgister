// ============================================================
// top : bộ xử lý ARM Single-Cycle + bộ nhớ lệnh + bộ nhớ dữ liệu
// (Harris & Harris, Digital Design and Computer Architecture:
//  ARM Edition, Chương 7 - Hình 7.13, 7.14, 7.16, 7.17)
//
// Tập lệnh đã xây dựng:
//   - Data-processing: 16 opcode (AND EOR SUB RSB ADD ADC SBC RSC
//     TST TEQ CMP CMN ORR MOV BIC MVN), có/không S
//   - Operand2: hằng xoay (imm8 ROR 2*rot4), thanh ghi dịch LSL/LSR/ASR/ROR/RRX
//     bởi hằng số hoặc bởi thanh ghi
//   - LDR/STR từ (word, offset imm12 dương, pre-index, không writeback)
//   - B và thực thi có điều kiện (15 mã Cond)
// Không hỗ trợ: BL, byte/halfword, offset thanh ghi/âm, writeback,
//               MUL, LDM/STM, MRS/MSR/BX, chế độ đặc quyền.
// ============================================================
module top(input  logic        clk, reset,
           output logic [31:0] WriteData, DataAdr,
           output logic        MemWrite);

  logic [31:0] PC, Instr, ReadData;

  // instantiate processor and memories
	arm arm_i(
				.clk       (clk),
				.reset     (reset),
				.PC        (PC),
				.Instr     (Instr),
				.MemWrite  (MemWrite),
				.ALUResult (DataAdr),
				.WriteData (WriteData),
				.ReadData  (ReadData)
	);
  imem imem_i(
    .a  (PC),
    .rd (Instr)
  );
  // Chặn ghi RAM trong lúc reset: khi reset, PC = 0 và lệnh đầu tiên đã hiện ra
  // (nếu là STR thì MemWrite = 1) -> sẽ ghi nhầm vào bộ nhớ dữ liệu.
  dmem dmem_i(
    .clk   (clk),
    .reset (reset),
    .we    (MemWrite),
    .a     (DataAdr),
    .wd    (WriteData),
    .rd    (ReadData)
  );
endmodule