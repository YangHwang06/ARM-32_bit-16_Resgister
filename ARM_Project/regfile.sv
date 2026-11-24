// ============================================================
// REGISTER FILE: R0-R14 reset to zero; R15 is supplied as PC+8
// ============================================================
module regfile(input logic clk, reset, we3,
               input logic [3:0] ra1, ra2, wa3,
               input logic [31:0] wd3, r15,
               input logic [3:0] ra3,
               output logic [31:0] rd1, rd2, rd3);
  logic [31:0] rf [0:14];

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      for (int i = 0; i < 15; i++)
        rf[i] <= 32'b0;
    end else if (we3 && (wa3 != 4'hF)) begin
      rf[wa3] <= wd3;
    end
  end

  assign rd1 = (ra1 == 4'hF) ? r15 : rf[ra1];
  assign rd2 = (ra2 == 4'hF) ? r15 : rf[ra2];
  assign rd3 = (ra3 == 4'hF) ? r15 : rf[ra3];
endmodule