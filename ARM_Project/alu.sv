// ============================================================
// ALU: AND,EOR,SUB,RSB,ADD,ADC,SBC,RSC,TST,TEQ,CMP,CMN,ORR,MOV,BIC,MVN
// Flags are returned as {N,Z,C,V}.
// ============================================================
module alu(input logic [31:0] a, b,
           input logic [3:0] ALUControl,
           input logic ShifterCarry, CarryIn,
           output logic [31:0] Result,
           output logic [3:0] ALUFlags);
  logic [31:0] opA, opB;
  logic [32:0] sum;
  logic arithmetic, subtract;
  logic N, Z, C, V;

  always_comb begin
    Result     = 32'b0;
    opA        = a;
    opB        = b;
    sum        = 33'b0;
    arithmetic = 1'b0;
    subtract   = 1'b0;

    case (ALUControl)
      4'h0, 4'h8: Result = a & b; // AND / TST
      4'h1, 4'h9: Result = a ^ b; // EOR / TEQ
      4'h2, 4'hA: begin          // SUB / CMP
        arithmetic = 1'b1;
        subtract   = 1'b1;
        sum = {1'b0,a} + {1'b0,~b} + 33'd1;
      end
      4'h3: begin                // RSB: b-a
        arithmetic = 1'b1;
        subtract   = 1'b1;
        opA = b;
        opB = a;
        sum = {1'b0,b} + {1'b0,~a} + 33'd1;
      end
      4'h4, 4'hB: begin          // ADD / CMN
        arithmetic = 1'b1;
        sum = {1'b0,a} + {1'b0,b};
      end
      4'h5: begin                // ADC
        arithmetic = 1'b1;
        sum = {1'b0,a} + {1'b0,b} + CarryIn;
      end
      4'h6: begin                // SBC: a-b-(1-C)
        arithmetic = 1'b1;
        subtract   = 1'b1;
        sum = {1'b0,a} + {1'b0,~b} + CarryIn;
      end
      4'h7: begin                // RSC: b-a-(1-C)
        arithmetic = 1'b1;
        subtract   = 1'b1;
        opA = b;
        opB = a;
        sum = {1'b0,b} + {1'b0,~a} + CarryIn;
      end
      4'hC: Result = a | b;      // ORR
      4'hD: Result = b;          // MOV
      4'hE: Result = a & ~b;     // BIC
      4'hF: Result = ~b;         // MVN
      default: Result = 32'b0;
    endcase

    if (arithmetic)
      Result = sum[31:0];

    N = Result[31];
    Z = (Result == 32'b0);
    C = arithmetic ? sum[32] : ShifterCarry;
    V = 1'b0;

    if (arithmetic) begin
      if (subtract)
        V = (opA[31] != opB[31]) && (Result[31] != opA[31]);
      else
        V = (opA[31] == opB[31]) && (Result[31] != opA[31]);
    end

    ALUFlags = {N,Z,C,V};
  end
endmodule
