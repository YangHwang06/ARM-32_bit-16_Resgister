// ============================================================
// INSTRUCTION MEMORY: 64 words x 32 bits
// ============================================================
module imem(input logic [31:0] a,
            output logic [31:0] rd);
  logic [31:0] RAM [0:63];

  initial begin
    for (int i = 0; i < 64; i++)
      RAM[i] = 32'b0;
    $readmemh("C:/intelFPGA_lite/20.1/Project/Project final/memfile.dat", RAM);
  end

  assign rd = (a[31:8] == 24'b0 && a[1:0] == 2'b00)
              ? RAM[a[7:2]] : 32'b0;
endmodule