// ============================================================
// ARM OPERAND2 BARREL SHIFTER
// ============================================================
module operand2_shifter(input logic [31:0] Rm,
                        input logic [31:0] Rs,
                        input logic [11:0] Operand2Field,
                        input logic I,
                        input logic CarryIn,
                        output logic [31:0] Y,
                        output logic CarryOut);
  logic [7:0] imm8;
  logic [3:0] rotate_imm;
  logic [4:0] imm_shift;
  logic [1:0] shift_type;
  logic reg_shift;
  logic [7:0] amount;
  logic [7:0] n;

  always_comb begin
    Y          = Rm;
    CarryOut   = CarryIn;
    imm8       = Operand2Field[7:0];
    rotate_imm = Operand2Field[11:8];
    imm_shift  = Operand2Field[11:7];
    shift_type = Operand2Field[6:5];
    reg_shift  = Operand2Field[4];
    amount     = reg_shift ? Rs[7:0] : {3'b000, imm_shift};
    n          = 8'd0;

    if (I) begin
      n = {3'b000, rotate_imm, 1'b0};
      if (n == 8'd0) begin
        Y        = {24'b0, imm8};
        CarryOut = CarryIn;
      end else begin
        Y        = ({24'b0, imm8} >> n) | ({24'b0, imm8} << (8'd32 - n));
        CarryOut = Y[31];
      end
    end else if (reg_shift && amount == 8'd0) begin
      // Register-specified shift by zero preserves value and carry.
      Y        = Rm;
      CarryOut = CarryIn;
    end else if (!reg_shift && shift_type == 2'b00 && imm_shift == 5'd0) begin
      // LSL #0 preserves value and carry.
      Y        = Rm;
      CarryOut = CarryIn;
    end else begin
      case (shift_type)
        2'b00: begin // LSL
          if (amount < 8'd32) begin
            Y        = Rm << amount;
            CarryOut = Rm[8'd32 - amount];
          end else if (amount == 8'd32) begin
            Y        = 32'b0;
            CarryOut = Rm[0];
          end else begin
            Y        = 32'b0;
            CarryOut = 1'b0;
          end
        end

        2'b01: begin // LSR; immediate #0 means 32
          n = amount;
          if (!reg_shift && imm_shift == 5'd0) n = 8'd32;
          if (n < 8'd32) begin
            Y        = Rm >> n;
            CarryOut = Rm[n - 8'd1];
          end else if (n == 8'd32) begin
            Y        = 32'b0;
            CarryOut = Rm[31];
          end else begin
            Y        = 32'b0;
            CarryOut = 1'b0;
          end
        end

        2'b10: begin // ASR; immediate #0 means 32
          n = amount;
          if (!reg_shift && imm_shift == 5'd0) n = 8'd32;
          if (n < 8'd32) begin
            Y        = $signed(Rm) >>> n;
            CarryOut = Rm[n - 8'd1];
          end else begin
            Y        = {32{Rm[31]}};
            CarryOut = Rm[31];
          end
        end

        2'b11: begin // ROR; immediate #0 means RRX
          if (!reg_shift && imm_shift == 5'd0) begin
            Y        = {CarryIn, Rm[31:1]};
            CarryOut = Rm[0];
          end else begin
            n = {3'b000, amount[4:0]}; // tương đương amount % 32
            if (n == 8'd0) begin
              Y        = Rm;
              CarryOut = Rm[31];
            end else begin
              Y        = (Rm >> n) | (Rm << (8'd32 - n));
              CarryOut = Y[31];
            end
          end
        end

        default: begin
          Y        = Rm;
          CarryOut = CarryIn;
        end
      endcase
    end
  end
endmodule