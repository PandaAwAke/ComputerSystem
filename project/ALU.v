module ALU(
    input clk,
    input [3:0]  ALUCtr,
    input [31:0] in1,
    input [31:0] in2,
    output reg [31:0] out3,
    output reg [31:0] hi,
    output reg [2:0] out,
    output reg overflow
);

always @ (posedge clk) begin
    case (ALUCtr)
        4'd0: begin 
            out3 <= in1 + in2;
            out <= 3'd0;
        end
        4'd1: begin
            out3 <= in1 + in2;
            overflow <= (in1[31] == in2[31]) && (in1[31] != out3[31]);
        end
        4'd2: begin 
            out3 <= in1 - in2;
            out <= 3'd2;
        end
        4'd3: begin 
            out3 <= in1 - in2;
            overflow <= (in1[31] == 1'b1) && (in2[31] == 1'b0) && (in1[31] == 1'b0);
        end
        4'd4: begin 
            out3 <= ((((in1[31] == 1'b1) && (in2[31] == 1'b0)) || ((in1[31] == in2[31]) && (in1[30:0] < in2[30:0])))? 32'd1 : 32'd0);
            out <= 3'd4;
        end
        4'd5: begin 
            out3 <= ((in1 < in2)? 32'd1 : 32'd0);
            out <= 3'd5;
        end
        4'd6: begin 
            out3 <= in1 & in2;
            out <= 3'd6;
        end
        4'd7: begin 
            out3 <= in1 | in2;
            out <= 3'd7;
        end
        4'd8: begin 
            out3 <= in1 ^ in2;
            out <= 3'd7;
        end
        4'd9: begin 
            out3 <= ~(in1 | in2);
            out <= 3'd7;
        end
        4'd10: begin 
            out3 <= in2 << in1;
            out <= 3'd7;
        end
        4'd11: begin 
            out3 <= in2 >> in1;
            out <= 3'd7;
        end
        4'd12: begin 
            out3 <= in2 >>> in1;
            out <= 3'd7;
        end
        4'd13: begin 
            out3 <= ((in1 == in2)? 32'd1 : 32'd0);
            out <= 3'd7;
        end
        4'd14: begin
            {hi, out3} <= in2 * in1;
        end
        default: begin
            out3 <= 32'd0;
            out <= 3'd0;
        end
    endcase
end

endmodule
