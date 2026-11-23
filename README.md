# ARMv4 32-bit Single-Cycle Processor (16-Register Architecture)

Thiết kế và mô phỏng bộ xử lý **ARMv4 32-bit đơn chu kỳ (Single-Cycle)** bằng ngôn ngữ mô tả phần cứng **SystemVerilog**, phát triển dựa trên kiến trúc chuẩn trong giáo trình *Digital Design and Computer Architecture (ARM Edition)* — Sarah L. Harris & David Harris.

Dự án bao gồm đầy đủ khối đường dẫn dữ liệu (Datapath), khối điều khiển (Controller), bộ dịch thanh ghi (Barrel Shifter), hệ thống cờ trạng thái 4-bit độc lập và bộ kiểm thử tự động (Self-Checking Testbench) xác minh 35 lệnh hợp ngữ ARMv4.

---

## Tính năng kiến trúc nổi bật

- **Độ rộng dữ liệu & địa chỉ:** 32-bit (`[31:0]`), hỗ trợ không gian địa chỉ định byte.
- **Tập thanh ghi (Register File):** 16 thanh ghi đa dụng 32-bit (`R0` – `R15`), trong đó `R15` đóng vai trò bộ đếm chương trình (`PC`) và tự động tính toán giá trị `PC + 8` theo chuẩn pipeline 3 tầng của ARMv4.
- **Khối ALU 32-bit mở rộng:** Hỗ trợ đầy đủ 16 mã lệnh xử lý dữ liệu (`AND`, `EOR`, `SUB`, `RSB`, `ADD`, `ADC`, `SBC`, `RSC`, `TST`, `TEQ`, `CMP`, `CMN`, `ORR`, `MOV`, `BIC`, `MVN`).
- **Bộ dịch thanh ghi (Barrel Shifter):** Hỗ trợ dịch chuyển toán hạng thứ hai (`Operand2`) trực tiếp trong một chu kỳ xung nhịp với các chế độ `LSL`, `LSR`, `ASR`, `ROR` (dịch theo hằng số `shamt5` hoặc giá trị thanh ghi `Rs`).
- **Quản lý cờ trạng thái (`CPSR`):** Tín hiệu điều khiển `FlagW[3:0]` cho phép cập nhật độc lập nhóm cờ số học (`C`, `V`) và cờ logic (`N`, `Z`) khi lệnh có hậu tố `S`.
- **Thực thi có điều kiện (Conditional Execution):** Kiểm tra 4-bit trường `Cond[31:28]` của mọi lệnh trước khi cho phép ghi thanh ghi, ghi bộ nhớ hoặc nhảy (`PCSrc`).

---

## Cấu trúc thư mục dự án

```text
ARM-32_bit-16_Resgister/
├── rtl/                        # Mã nguồn thiết kế phần cứng (Synthesizable SystemVerilog)
│   ├── top.sv                  # Mô-đun cấp cao nhất kết nối lõi ARM, IMEM và DMEM
│   ├── arm.sv                  # Lõi xử lý ARM kết nối Controller và Datapath
│   ├── controller.sv           # Khối điều khiển trung tâm
│   ├── decoder.sv              # Bộ giải mã lệnh (Main Decoder, ALU Decoder, PC Logic)
│   ├── condlogic.sv            # Khối kiểm tra điều kiện và chốt cờ trạng thái (N, Z, C, V)
│   ├── datapath.sv             # Đường dẫn dữ liệu 32-bit
│   ├── regfile.sv              # Tập thanh ghi 16 x 32-bit (2 cổng đọc, 1 cổng ghi)
│   ├── alu.sv                  # Khối tính toán số học và logic 32-bit
│   ├── operand2_shifter.sv     # Bộ dịch Barrel Shifter 32-bit
│   ├── extend.sv               # Khối mở rộng hằng số tức thời (Immediate Extension)
│   ├── imem.sv                 # Bộ nhớ lệnh (Instruction Memory - ROM)
│   └── dmem.sv                 # Bộ nhớ dữ liệu (Data Memory - RAM)
├── sim/                        # Môi trường kiểm thử và dữ liệu mô phỏng
│   ├── tb_top.sv               # Testbench tự động kiểm tra (Self-checking)
│   └── memfile.dat             # Mã máy hệ thập lục phân (Hex) của chương trình 35 lệnh
├── docs/                       # Hình ảnh sơ đồ RTL Viewer, dạng sóng và báo cáo LaTeX
└── README.md
