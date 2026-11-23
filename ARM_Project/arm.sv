// ============================================================
// ARM CORE
// ============================================================
module arm(input logic clk, reset,
           output logic [31:0] PC,
           input logic [31:0] Instr,
           output logic MemWrite,
           output logic [31:0] ALUResult, WriteData,
           input logic [31:0] ReadData);
  logic [3:0] ALUFlags;
  logic RegWrite, ALUSrc, MemtoReg, PCSrc;
  logic [1:0] RegSrc, ImmSrc;
  logic [3:0] ALUControl;
  logic [3:0] FlagW, CurrentFlags;

  controller c(clk, reset, Instr[31:12], ALUFlags,
               RegSrc, RegWrite, ImmSrc, ALUSrc, ALUControl,
               FlagW, CurrentFlags, MemWrite, MemtoReg, PCSrc);

  datapath dp(clk, reset, RegSrc, RegWrite, ImmSrc, ALUSrc,
              ALUControl, MemtoReg, PCSrc, FlagW, CurrentFlags[1],
              ALUFlags, PC, Instr, ALUResult, WriteData, ReadData);
endmodule

// ============================================================
// CONTROL PATH
// ============================================================
module controller(input logic clk, reset,
                  input logic [31:12] Instr,
                  input logic [3:0] ALUFlags,
                  output logic [1:0] RegSrc,
                  output logic RegWrite,
                  output logic [1:0] ImmSrc,
                  output logic ALUSrc,
                  output logic [3:0] ALUControl,
                  output logic [3:0] FlagW,
                  output logic [3:0] CurrentFlags,
                  output logic MemWrite, MemtoReg, PCSrc);
  logic PCS, RegW, MemW;
  logic [3:0] Cond;

  decoder dec(Instr[27:26], Instr[25:20], Instr[15:12], Instr[24],
              RegSrc, ImmSrc, ALUSrc, MemtoReg,
              RegW, MemW, PCS, ALUControl, FlagW);

  assign Cond = Instr[31:28];

  condlogic cl(clk, reset, Cond, ALUFlags, FlagW,
               PCS, RegW, MemW,
               PCSrc, RegWrite, MemWrite, CurrentFlags);
endmodule

// ============================================================
// DECODER
// ============================================================
module decoder(input logic [1:0] Op,
               input logic [5:0] Funct,
               input logic [3:0] Rd,
               input logic Link,
               output logic [1:0] RegSrc,
               output logic [1:0] ImmSrc,
               output logic ALUSrc, MemtoReg,
               output logic RegW, MemW, PCS,
               output logic [3:0] ALUControl,
               output logic [3:0] FlagW);
  logic [3:0] opcode;
  logic S;

  always_comb begin
    // Safe defaults: unsupported encodings do nothing.
    RegSrc     = 2'b00;
    ImmSrc     = 2'b00;
    ALUSrc     = 1'b0;
    MemtoReg   = 1'b0;
    RegW       = 1'b0;
    MemW       = 1'b0;
    PCS        = 1'b0;
    ALUControl = 4'b0100;
    FlagW      = 4'b0000;

    opcode = Funct[4:1];
    S      = Funct[0];

    case (Op)
      2'b00: begin // Data Processing
        RegW       = 1'b1;
        ALUControl = opcode;

        // TST, TEQ, CMP, CMN: flags only, no destination write.
        case (opcode)
          4'b1000, 4'b1001, 4'b1010, 4'b1011: begin
            RegW    = 1'b0;
          end
          default: ;
        endcase

        // Test instructions always update flags; other DP ops only if S=1.
        if (S || (opcode >= 4'b1000 && opcode <= 4'b1011)) begin
          FlagW[3:2] = 2'b11; // N,Z
          case (opcode)
            4'b0000, 4'b0001, 4'b1100, 4'b1101,
            4'b1110, 4'b1111, 4'b1000, 4'b1001:
              FlagW[1:0] = 2'b10; // C from shifter; preserve V
            default:
              FlagW[1:0] = 2'b11; // arithmetic C,V
          endcase
        end

        // MOV/MVN do not use Rn. The ALU ignores SrcA for these opcodes.
        if (opcode == 4'b1101 || opcode == 4'b1111)
          RegSrc[0] = 1'b0;

        // Support non-S data-processing writes to PC only.
        // DP with S=1 and Rd=PC requires exception-return semantics (SPSR),
        // which this processor does not implement: treat it as unsupported.
        if (Rd == 4'hF) begin
          if (RegW && !S) begin
            PCS = 1'b1;
          end else begin
            RegW    = 1'b0;
            FlagW   = 4'b0000;
          end
        end
      end

      2'b01: begin // Word LDR/STR, immediate, P=1, U=1, B=0, W=0
        // Funct = Instr[25:20] = {I,P,U,B,W,L}.
        // Only 0_1_1_0_0_L is implemented.
        if (Funct[5:1] == 5'b01100) begin
          ImmSrc   = 2'b01;
          ALUSrc   = 1'b1;
          ALUControl = 4'b0100; // base + positive immediate offset

          if (Funct[0]) begin // LDR
            // LDR into PC is not implemented in this subset.
            if (Rd != 4'hF) begin
              RegW     = 1'b1;
              MemtoReg = 1'b1;
            end
          end else begin // STR
            RegSrc[1] = 1'b1; // store data comes from Rd
            MemW      = 1'b1;
          end
        end
      end

      2'b10: begin // B only; BL (bit 24 = 1) is unsupported
        if (!Link) begin
          RegSrc     = 2'b01; // read PC as Rn (PC+8)
          ImmSrc     = 2'b10; // sign-extend imm24 and shift left 2
          ALUSrc     = 1'b1;
          ALUControl = 4'b0100; // PC+8 + branch offset
          PCS        = 1'b1;
        end
      end

      default: ;
    endcase
  end
endmodule

// ============================================================
// CONDITIONAL EXECUTION AND FLAG REGISTERS
// ============================================================
module condlogic(input logic clk, reset,
                 input logic [3:0] Cond,
                 input logic [3:0] ALUFlags,
                 input logic [3:0] FlagW,
                 input logic PCS, RegW, MemW,
                 output logic PCSrc, RegWrite, MemWrite,
                 output logic [3:0] CurrentFlags);
  logic [3:0] Flags;
  logic CondEx;

  genvar i;
  generate
    for (i = 0; i < 4; i++) begin : flag_bits
      flopenr #(1) flagreg(clk, reset, FlagW[i] & CondEx,
                           ALUFlags[i], Flags[i]);
    end
  endgenerate

  assign CurrentFlags = Flags;
  condcheck cc(Cond, Flags, CondEx);

  assign RegWrite = RegW & CondEx;
  assign MemWrite = MemW & CondEx;
  assign PCSrc    = PCS & CondEx;
endmodule

// ============================================================
// CONDITION CHECK
// ============================================================
module condcheck(input logic [3:0] Cond,
                 input logic [3:0] Flags,
                 output logic CondEx);
  logic N, Z, C, V;
  assign {N,Z,C,V} = Flags;

  always_comb begin
    case (Cond)
      4'h0: CondEx =  Z;             // EQ
      4'h1: CondEx = ~Z;             // NE
      4'h2: CondEx =  C;             // CS/HS
      4'h3: CondEx = ~C;             // CC/LO
      4'h4: CondEx =  N;             // MI
      4'h5: CondEx = ~N;             // PL
      4'h6: CondEx =  V;             // VS
      4'h7: CondEx = ~V;             // VC
      4'h8: CondEx =  C & ~Z;        // HI
      4'h9: CondEx = ~C | Z;         // LS
      4'hA: CondEx = (N == V);       // GE
      4'hB: CondEx = (N != V);       // LT
      4'hC: CondEx = ~Z & (N == V);  // GT
      4'hD: CondEx =  Z | (N != V);  // LE
      4'hE: CondEx = 1'b1;          // AL
      default: CondEx = 1'b0;        // NV
    endcase
  end
endmodule

// ============================================================
// DATAPATH
// ============================================================
module datapath(input logic clk, reset,
                input logic [1:0] RegSrc,
                input logic RegWrite,
                input logic [1:0] ImmSrc,
                input logic ALUSrc,
                input logic [3:0] ALUControl,
                input logic MemtoReg, PCSrc,
                input logic [3:0] FlagW,
                input logic CarryFlag,
                output logic [3:0] ALUFlags,
                output logic [31:0] PC,
                input logic [31:0] Instr,
                output logic [31:0] ALUResult, WriteData,
                input logic [31:0] ReadData);
  logic [31:0] PCNext, PCPlus4, PCPlus8, ExtImm;
  logic [31:0] SrcA, SrcB, Result, RmData, RsData, ShifterOut;
  logic ShifterCarry;
  logic [3:0] RA1, RA2;

  mux2 #(32) pcmux(PCPlus4, Result, PCSrc, PCNext);
  flopr #(32) pcreg(clk, reset, PCNext, PC);
  adder #(32) pcadd1(PC, 32'd4, PCPlus4);
  adder #(32) pcadd2(PCPlus4, 32'd4, PCPlus8);

  mux2 #(4) ra1mux(Instr[19:16], 4'hF, RegSrc[0], RA1);
  mux2 #(4) ra2mux(Instr[3:0], Instr[15:12], RegSrc[1], RA2);

  regfile rf(clk, reset, RegWrite, RA1, RA2, Instr[15:12],
             Result, PCPlus8, Instr[11:8], SrcA, RmData, RsData);

  extend ext(Instr[23:0], ImmSrc, ExtImm);
  operand2_shifter sh(RmData, RsData, Instr[11:0],
                      Instr[25], CarryFlag, ShifterOut, ShifterCarry);

  // DP uses shifted Rm; memory and branch use ExtImm.
  mux2 #(32) srcbmux(ShifterOut, ExtImm, ALUSrc, SrcB);
  assign WriteData = RmData;

  alu alu_i(SrcA, SrcB, ALUControl, ShifterCarry, CarryFlag,
            ALUResult, ALUFlags);
  mux2 #(32) resmux(ALUResult, ReadData, MemtoReg, Result);
endmodule
