// ============================================================
// DATA MEMORY: 64 words x 32 bits (byte address 0..255)
// ============================================================
module dmem(input logic clk, reset, we,
            input logic [31:0] a, wd,
            output logic [31:0] rd);
  logic [31:0] RAM [0:63];
  logic addr_valid;

  assign addr_valid = (a[31:8] == 24'b0) && (a[1:0] == 2'b00);
  assign rd = addr_valid ? RAM[a[7:2]] : 32'bx;

  // RAM dữ liệu không reset: reset CPU không xóa nội dung bộ nhớ.
  // Tuy nhiên, không nhận giao dịch ghi khi reset đang ở mức 1.
  always_ff @(posedge clk) begin
    if (!reset && we && addr_valid)
      RAM[a[7:2]] <= wd;
  end
endmodule