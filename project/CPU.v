module CPU(
    input clk,
    input clrn,
    input key_clk,
    output [31:0] pc,
    output [31:0] Instr,
    output [31:0] r2,
    output [31:0] r8,
    output [31:0] r9,
    output [31:0] r10,
    output [31:0] r11,
    output [31:0] r12,
    output [31:0] r16,
    output [31:0] r17,
    output [31:0] HI,
    output [31:0] LO,
    output [31:0] sp,

    output audio_ena,
    output [5:0] State,

    output  reg  solved,
    input        video_solved,
    output  reg  require_input,
    input        input_valid,

    input        out_ready,
    output  reg  out_end_n,
    output reg [7:0] ascii_out,
    
    output  reg  in_ready,
    input        in_end_n,
    input [12:0] lineLen,
    input  [7:0] ascii_in
);

(* ram_init_file = "init_files/main_memory" *) reg [31:0] main_memory [16*1024-1:0];
(* ram_init_file = "init_files/instr_ram" *) reg [31:0] instr_ram [1023:0];
reg [31:0] PC = 32'h400000, hi, lo;
wire [31:0] div_hi, div_lo, mul_hi;
reg [31:0] register[31:0];
reg [31:0] instr;
reg [31:0] index;

assign audio_ena = register[27][4];

assign HI = hi;
assign LO = lo;

assign Instr = instr;
assign pc = PC;
assign r2 = register[2];
assign r8 = register[8];
assign r9 = register[9];
assign r10 = register[10];
assign r11 = register[11];
assign r12 = register[12];
assign r16 = register[16];
assign r17 = register[17];
assign sp = register[29];
/*
reg instr_fetch_ena = 1'b1;
reg decode_ena = 1'b0;
reg exec_ena = 1'b0;
reg access_ena = 1'b0;
reg write_back_ena = 1'b0;
*/
//reg jmp_ena = 1'b0;
//reg [31:0] jmp_dest = 32'h0;

wire [5:0] op = instr[31:26];
wire [4:0] rs = instr[25:21];
wire [4:0] rt = instr[20:16];
wire [4:0] rd = instr[15:11];
wire [4:0] shamt = instr[10:6];
wire [5:0] func = instr[5:0];
wire [15:0] imm = instr[15:0];
wire [25:0] addr = instr[25:0];

reg [5:0] state = 6'd0;
reg [31:0] output_remain;

assign State = state;

wire [31:0] ALUout;
reg [31:0] ALUin1, ALUin2;
reg [3:0] ALUop;
wire overflow;

wire [7:0] tmp_ascii;

task HEX2ASCII;
    input [3:0] HEX;
    output reg [7:0] ASCII;
    begin
        if (HEX > 4'h9)
            ASCII = {4'h0, HEX} + 8'h37;
        else
            ASCII = {4'h0, HEX} + 8'h30;
    end
endtask

ALU alu(
    .clk(clk),
    .ALUCtr(ALUop),   
    .in1(ALUin1),
    .in2(ALUin2),
    .out3(ALUout),
    .hi(mul_hi),
    .out(),
    .overflow(overflow)
);

reg div_start = 1'b0;
wire [31:0] q, r;

wire div_end;

DIV div(
    .clk(clk),
    .dividend(ALUin1),
    .divisor(ALUin2),
    .div_start(div_start),
    .div_end(div_end),
    .q(div_lo),
    .r(div_hi)
);

initial begin
    register[0] = 32'd0; //zero
    register[29] = 32'h7fffeffc; //sp
    register[26] = 32'h7fff0000; //input start addr
    register[27] = 32'h1; //control register
    solved = 1'b0;
    out_end_n = 1'b0;
    ascii_out = 8'h0;
    require_input = 1'b0;
    in_ready = 1'b0;
end

reg [2:0] key_sync;

always @ (posedge clk) begin
    key_sync <= {key_sync[1:0], key_clk};
end
    
wire key_samp = key_sync[2] & ~key_sync[1];

always @ (posedge clk) begin
    /*
    if (clrn == 1'b0) begin
        PC <= 32'h400000;
        state <= 6'd5;
        //jmp_ena <= 1'b0;
        register[29] <= 32'h7fffeffc;
        register[26] <= 32'h7fff0000;
        register[27] <= 32'h1;
    end
    else begin
    */
        case (state)
            6'd0: begin //wait for enter
                if (in_end_n) begin
                    in_ready <= 1'b1;
                    state <= 6'd1;
                    //index <= 32'h7FFF0000;
                    ALUop <= 4'd0;
                    ALUin1 <= register[26];
                    ALUin2 <= 32'h0;
                end
            end
            6'd1: begin
                //main_memory[index[15:2]] <= {24'h0, ascii_in};
                //index <= index + 32'd4;
                main_memory[ALUout[15:2]] <= {24'h0, ascii_in};
                ALUop <= 4'd0;
                ALUin1 <= ALUout;
                ALUin2 <= 32'h4;

                if (ascii_in == 8'h0) begin
                    in_ready <= 1'b0;
                    state <= 6'd2;
                end
            end
            6'd2: begin // instr_fetch
                //if (jmp_ena) begin
                //    PC <= jmp_dest + 32'd4;
                //    instr <= instr_ram[jmp_dest[11:2]];
                //    jmp_ena <= 1'b0;
                //end
                //else begin
                    PC <= PC + 32'd4;
                    instr <= instr_ram[PC[11:2]];
                //end
                if (register[27][3] == 1'b1 || clrn == 1'b0) begin //end
                    //out <= register[2];
                    solved <= 1'b1;
                    /*
                    PC <= 32'h400000;
                    register[29] <= 32'h7fffeffc;
                    register[27] <= {27'h0, register[27][4], 4'h1};
                    register[26] <= 32'h7fff0000;
                    */
                    state <= 6'd12;
                end
                else if (register[27][1] == 1'b1) begin //require output
                    register[27] <= {register[27][31:2], 1'b0, register[27][0]};
                    state <= 6'd7;
                end
                else if (register[27][2] == 1'b1) begin //require input
                    register[27] <= {register[27][31:3], 1'b0, register[27][1:0]};
                    require_input <= 1'b1;
                    state <= 6'd36;
                end            
                else
                    state <= 6'd3;
            end
            6'd3: begin //decode
                case (op)            
                    6'h0: case (func)
                        6'b100000, 6'b100001: begin
                            ALUop <= 4'd1;
                            ALUin1 <= register[rs];
                            ALUin2 <= register[rt];
                        end
                        6'b100010, 6'b100011: begin
                            ALUop <= 4'd3;
                            ALUin1 <= register[rs];
                            ALUin2 <= register[rt];
                        end
                        6'b101010: begin
                            ALUop <= 4'd4;
                            ALUin1 <= register[rs];
                            ALUin2 <= register[rt];
                        end
                        6'b101011: begin
                            ALUop <= 4'd5;
                            ALUin1 <= register[rs];
                            ALUin2 <= register[rt];
                        end
                        6'b100100: begin
                            ALUop <= 4'd6;
                            ALUin1 <= register[rs];
                            ALUin2 <= register[rt];
                        end
                        6'b100101: begin
                            ALUop <= 4'd7;
                            ALUin1 <= register[rs];
                            ALUin2 <= register[rt];
                        end
                        6'b100110: begin
                            ALUop <= 4'd8;
                            ALUin1 <= register[rs];
                            ALUin2 <= register[rt];
                        end
                        6'b100111: begin
                            ALUop <= 4'd9;
                            ALUin1 <= register[rs];
                            ALUin2 <= register[rt];
                        end
                        6'b000000: begin
                            ALUop <= 4'd10;
                            ALUin1 <= {27'b0, shamt[4:0]};
                            ALUin2 <= register[rt];
                        end
                        6'b000010: begin
                            ALUop <= 4'd11;
                            ALUin1 <= {27'b0, shamt[4:0]};
                            ALUin2 <= register[rt];
                        end
                        6'b000011: begin
                            ALUop <= 4'd12;
                            ALUin1 <= {27'b0, shamt[4:0]};
                            ALUin2 <= register[rt];
                        end
                        6'b000100: begin
                            ALUop <= 4'd10;
                            ALUin1 <= register[rs];
                            ALUin2 <= register[rt];
                        end
                        6'b000110: begin
                            ALUop <= 4'd11;
                            ALUin1 <= register[rs];
                            ALUin2 <= register[rt];
                        end
                        6'b000111: begin
                            ALUop <= 4'd12;
                            ALUin1 <= register[rs];
                            ALUin2 <= register[rt];
                        end
                        //6'b001000: begin
                            
                        //end
                        6'b011000, 6'b011001: begin //mult, multu
                            ALUop <= 4'd14;
                            ALUin1 <= register[rs];
                            ALUin2 <= register[rt];
                        end
                        6'h1a, 6'h1b: begin //divu
                            ALUin1 <= register[rs];
                            ALUin2 <= register[rt];
                            div_start <= 1'b1;
                        end
                        //6'h12:  //mflo
                        //6'h10:  //mfhi
                        //default: 
                    endcase
                    6'b001000: begin
                        ALUop <= 4'd1;
                        ALUin1 <= register[rs];
                        ALUin2 <= {{16{imm[15]}}, imm};
                    end
                    6'b001001: begin
                        ALUop <= 4'd0;
                        ALUin1 <= register[rs];
                        ALUin2 <= {16'b0, imm};
                    end
                    6'b001010: begin
                        ALUop <= 4'd4;
                        ALUin1 <= register[rs];
                        ALUin2 <= {{16{imm[15]}}, imm};
                    end
                    6'b001011: begin
                        ALUop <= 4'd5;
                        ALUin1 <= register[rs];
                        ALUin2 <= {16'b0, imm};
                    end
                    6'b001100: begin
                        ALUop <= 4'd6;
                        ALUin1 <= register[rs];
                        ALUin2 <= {16'b0, imm};
                    end
                    6'b001101: begin
                        ALUop <= 4'd7;
                        ALUin1 <= register[rs];
                        ALUin2 <= {16'b0, imm};
                    end
                    6'b001110: begin
                        ALUop <= 4'd8;
                        ALUin1 <= register[rs];
                        ALUin2 <= {16'b0, imm};
                    end
                    //6'b001111: begin
                    //    
                    //end
                    6'b100011, 6'b101011: begin
                        ALUop <= 4'd0;
                        ALUin1 <= register[rs];
                        ALUin2 <= {{16{imm[15]}}, imm};
                    end
                    6'b000100, 6'b000101: begin
                        ALUop <= 4'd13;
                        ALUin1 <= register[rs];
                        ALUin2 <= register[rt];
                    end
                    /*
                    6'b000010: begin
                        
                    end
                    6'b000011: begin
                        
                    end
                    
                    default: */
                endcase
                state <= 6'd4;
            end
            6'd4: begin //exec
                if (div_start) begin
                    div_start <= 1'b0;
                    state <= 6'd5;
                end
                else
                    state <= 6'd6;
            end
            6'd5: begin //wait for div end
                if (div_end) begin
                    state <= 6'd6;
                    lo <= div_lo;
                    hi <= div_hi;
                end
            end  
            6'd6: begin //write back
                case (op)            
                    6'h0: case (func)
                        6'b100000, 6'b100011: begin
                            if (overflow == 1'b0)
                                register[rd] <= ALUout;
                        end
                        6'b100001: register[rd] <= ALUout;
                        6'b100010: register[rd] <= ALUout;
                        6'b101010: register[rd] <= ALUout;
                        6'b101011: register[rd] <= ALUout;
                        6'b100100: register[rd] <= ALUout;
                        6'b100101: register[rd] <= ALUout;
                        6'b100110: register[rd] <= ALUout;
                        6'b100111: register[rd] <= ALUout;
                        6'b000000: register[rd] <= ALUout;
                        6'b000010: register[rd] <= ALUout;
                        6'b000011: register[rd] <= ALUout;
                        6'b000100: register[rd] <= ALUout;
                        6'b000110: register[rd] <= ALUout;
                        6'b000111: register[rd] <= ALUout;
                        6'b001000: PC <= register[rs];
                        6'h12: register[rd] <= lo; //mflo
                        6'h10: register[rd] <= hi; //mfhi
                        6'b011000, 6'b011001:  //mult, multu
                        begin
                            lo <= ALUout;
                            hi <= mul_hi;
                        end
                        //default: 
                    endcase
                    6'b001000: begin
                        if (overflow == 1'b0)
                            register[rt] <= ALUout;
                    end
                    6'b001001: register[rt] <= ALUout;
                    6'b001010: register[rt] <= ALUout;
                    6'b001011: register[rt] <= ALUout;
                    6'b001100: register[rt] <= ALUout;
                    6'b001101: register[rt] <= ALUout;
                    6'b001110: register[rt] <= ALUout;
                    6'b001111: register[rt] <= {imm, 16'b0};
                    6'b100011: register[rt] <= main_memory[ALUout[15:2]];
                    6'b101011: main_memory[ALUout[15:2]] <= register[rt];
                    6'b000100: begin
                        if (ALUout[0] == 1'b1)
                            PC <= PC + {{14{imm[15]}}, imm, 2'b0};
                        else
                            PC <= PC;
                    end
                    6'b000101: begin
                        if (ALUout[0] == 1'b0)
                            PC <= PC + {{14{imm[15]}}, imm, 2'b0};
                        else
                            PC <= PC;
                    end
                    6'b000010: PC <= {PC[31:28], addr, 2'b0};
                    6'b000011: begin
                        register[31] <= PC;
                        PC <= {PC[31:28], addr, 2'b0};
                    end                    
                endcase
                if (register[27][0] == 1'b0)
                    state <= 6'd2;
                else
                    state <= 6'd13;
            end         
            6'd7: begin //output
                //index <= register[29];
                ALUop <= 4'd0;
                ALUin1 <= register[29];
                ALUin2 <= 32'h0;
                state <= 6'd8;
            end
            6'd8: begin
                output_remain <= main_memory[ALUout[15:2]];
                ALUop <= 4'd0;
                ALUin1 <= ALUout;
                ALUin2 <= 32'h4;
                state <= 6'd10;
            end
            6'd10: begin
                //ascii_out <= main_memory[index[15:2]][7:0];
                ascii_out <= main_memory[ALUout[15:2]][7:0];
                out_end_n <= 1'b1;
                ALUop <= 4'd0;
                ALUin1 <= ALUout;
                ALUin2 <= 32'h4;
                //index <= index + 32'd4;
                output_remain <= output_remain - 32'd1;
                state <= 6'd11;
            end
            6'd11: begin
                ALUop <= 4'd0;
                ALUin1 <= ALUout; 
                if (out_ready) begin
                    if (output_remain == 32'd0) begin
                        out_end_n <= 1'b0;
                        state <= 6'd2;
                        //ALUin2 <= 32'h0;
                    end
                    else begin
                        //ascii_out <= main_memory[index[15:2]][7:0];
                        ascii_out <= main_memory[ALUout[15:2]][7:0];
                        //index <= index + 32'd4;
                        //ALUin2 <= 32'h4;
                        output_remain <= output_remain - 32'd1;
                    end
                    ALUin2 <= 32'h4;
                end
                else
                    ALUin2 <= 32'h0;
            end
            6'd12: begin //end of program
                if (video_solved) begin
                    PC <= 32'h400000;
                    register[29] <= 32'h7fffeffc;
                    register[27] <= {27'h0, register[27][4], 4'h1};
                    register[26] <= 32'h7fff0000;
                    out_end_n <= 1'b0;
                    require_input <= 1'b0;
                    in_ready <= 1'b0;
                    solved <= 1'b0;
                    state <= 6'd0;
                end
            end            
            6'd13: begin //0, single run print
                ascii_out <= 8'h30;
                out_end_n <= 1'b1;
                state <= 6'd14; 
            end
            6'd14: begin //x
                if (out_ready) begin
                    ascii_out <= 8'h78;
                    state <= 6'd15; 
                end
            end
            6'd15: begin //PC
                if (out_ready) begin
                    HEX2ASCII(PC[31:28], tmp_ascii);
                    ascii_out <= tmp_ascii;
                    state <= 6'd16;
                end
            end
            6'd16: begin 
                if (out_ready) begin
                    HEX2ASCII(PC[27:24], tmp_ascii);
                    ascii_out <= tmp_ascii;
                    state <= 6'd17;
                end
            end
            6'd17: begin 
                if (out_ready) begin
                    HEX2ASCII(PC[23:20], tmp_ascii);
                    ascii_out <= tmp_ascii;
                    state <= 6'd18;
                end
            end
            6'd18: begin 
                if (out_ready) begin
                    HEX2ASCII(PC[19:16], tmp_ascii);
                    ascii_out <= tmp_ascii;
                    state <= 6'd19;
                end
            end
            6'd19: begin 
                if (out_ready) begin
                    HEX2ASCII(PC[15:12], tmp_ascii);
                    ascii_out <= tmp_ascii;
                    state <= 6'd20;
                end
            end
            6'd20: begin
                if (out_ready) begin
                    HEX2ASCII(PC[11:8], tmp_ascii);
                    ascii_out <= tmp_ascii;
                    state <= 6'd21;
                end
            end
            6'd21: begin
                if (out_ready) begin
                    HEX2ASCII(PC[7:4], tmp_ascii);
                    ascii_out <= tmp_ascii;
                    state <= 6'd22;
                end
            end
            6'd22: begin
                if (out_ready) begin
                    HEX2ASCII(PC[3:0], tmp_ascii);
                    ascii_out <= tmp_ascii;
                    state <= 6'd23;
                end
            end
            6'd23: begin //:
                if (out_ready) begin
                    ascii_out <= 8'h3A;         
                    state <= 6'd24;
                end
            end
            6'd24: begin //space 
                if (out_ready) begin
                    ascii_out <= 8'h20;                 
                    state <= 6'd25;
                end
            end
            6'd25: begin //instr
                if (out_ready) begin
                    HEX2ASCII(instr[31:28], tmp_ascii);
                    ascii_out <= tmp_ascii;
                    state <= 6'd26;
                end
            end
            6'd26: begin
                if (out_ready) begin
                    HEX2ASCII(instr[27:24], tmp_ascii);
                    ascii_out <= tmp_ascii;
                    state <= 6'd27;
                end
            end
            6'd27: begin
                if (out_ready) begin
                    HEX2ASCII(instr[23:20], tmp_ascii);
                    ascii_out <= tmp_ascii;
                    state <= 6'd28;
                end
            end
            6'd28: begin
                if (out_ready) begin
                    HEX2ASCII(instr[19:16], tmp_ascii);
                    ascii_out <= tmp_ascii;
                    state <= 6'd29;
                end
            end
            6'd29: begin
                if (out_ready) begin
                    HEX2ASCII(instr[15:12], tmp_ascii);
                    ascii_out <= tmp_ascii;
                    state <= 6'd30;
                end
            end
            6'd30: begin
                if (out_ready) begin
                    HEX2ASCII(instr[11:8], tmp_ascii);
                    ascii_out <= tmp_ascii;
                    state <= 6'd31;
                end
            end
            6'd31: begin
                if (out_ready) begin
                    HEX2ASCII(instr[7:4], tmp_ascii);
                    ascii_out <= tmp_ascii;
                    state <= 6'd32;
                end
            end
            6'd32: begin
                if (out_ready) begin
                    HEX2ASCII(instr[3:0], tmp_ascii);
                    ascii_out <= tmp_ascii;
                    state <= 6'd33;
                end
            end
            6'd33: begin //0(\n)
                if (out_ready) begin
                    ascii_out <= 8'h0;                   
                    state <= 6'd34;
                end
            end
            6'd34: begin
                if (out_ready) begin
                    state <= 6'd35;
                    out_end_n <= 1'b0;
                end
            end
            6'd35: begin
                if (key_samp)
                    state <= 6'd2;
                else if (clrn == 1'b0) begin
                    solved <= 1'b1;
                    state <= 6'd12;
                end
            end
            6'd36: begin //wait for video respond
                if (input_valid) begin
                    //in_ready <= 1'b1;
                    require_input <= 1'b0;
                    state <= 6'd0;
                end
            end
        endcase
    //end
end

endmodule
