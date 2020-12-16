module ALU(
    input clk,
    input [3:0]  ALUCtr,
    input [31:0] in1,
    input [31:0] in2,
    output [31:0] out3,
    output [31:0] hi,
    output overflow
);

wire [31:0] res0, res1, res2, res3, res4, res5, res6, res7, res8, res9, res10, res11, res12, res13;
wire [63:0] res14;
assign res0 = in1 + in2;
assign res1 = in1 + in2;
assign res2 = in1 - in2;
assign res3 = in1 - in2;
assign res4 = ((((in1[31] == 1'b1) && (in2[31] == 1'b0)) || ((in1[31] == in2[31]) && (in1[30:0] < in2[30:0])))? 32'd1 : 32'd0);
assign res5 = ((in1 < in2)? 32'd1 : 32'd0);
assign res6 = in1 & in2;
assign res7 = in1 | in2;
assign res8 = in1 ^ in2;
assign res9 = ~(in1 | in2);
assign res10 = in2 << in1;
assign res11 = in2 >> in1;
assign res12 = in2 >>> in1;
assign res13 = ((in1 == in2)? 32'd1 : 32'd0);
assign res14 = in2 * in1;

wire of1, of3;
assign of1 = (in1[31] == in2[31]) && (in1[31] != out3[31]);
assign of3 = (in1[31] == 1'b1) && (in2[31] == 1'b0) && (in1[31] == 1'b0);

function [31:0] selector_out;
    input [3:0] op;
    input [31:0] data0, data1, data2, data3, data4, data5, data6, data7, data8, data9, data10, data11, data12, data13, data14; 
    begin
        case (op)
            4'd0: selector_out = data0;
            4'd1: selector_out = data1;
            4'd2: selector_out = data2;
            4'd3: selector_out = data3;
            4'd4: selector_out = data4;
            4'd5: selector_out = data5;
            4'd6: selector_out = data6;
            4'd7: selector_out = data7;
            4'd8: selector_out = data8;
            4'd9: selector_out = data9;
            4'd10: selector_out = data10;
            4'd11: selector_out = data11;
            4'd12: selector_out = data12;
            4'd13: selector_out = data13;
            4'd14: selector_out = data14;
            default: selector_out = 32'd0;
        endcase
    end
endfunction

assign out3 = selector_out(ALUCtr, res0, res1, res2, res3, res4, res5, res6, res7, res8, res9, res10, res11, res12, res13, res14[31:0]);

function [31:0] selector_hi;
    input [3:0] op;
    input [31:0] data14; 
    begin
        case (op)
            4'd14: selector_hi = data14;
            default: selector_hi = 32'd0;
        endcase
    end
endfunction

assign hi = selector_hi(ALUCtr, res14[63:32]);

function selector_of;
    input [3:0] op;
    input data1, data3; 
    begin
        case (op)
            4'd1: selector_of = data1;
            4'd3: selector_of = data3;
            default: selector_of = 1'b0;
        endcase
    end
endfunction

assign overflow = selector_of(ALUCtr, of1, of3);
/*
always @ (*) begin
    case (ALUCtr)
        4'd0: begin
            {hi, out3} = {32'h0, res0};
            overflow = 0;
        end
        4'd1: begin
            {hi, out3} = {32'h0, res1};
            overflow = of1;
        end
        4'd2: begin
            {hi, out3} = {32'h0, res2};
            overflow = 0;
        end
        4'd3: begin 
            {hi, out3} = {32'h0, res3};
            overflow = of3;
        end
        4'd4: begin
            {hi, out3} = {32'h0, res4};
            overflow = 0;
        end
        4'd5: begin
            {hi, out3} = {32'h0, res5};
            overflow = 0;
        end
        4'd6: begin
            {hi, out3} = {32'h0, res6};
            overflow = 0;
        end
        4'd7: begin
            {hi, out3} = {32'h0, res7};
            overflow = 0;
        end
        4'd8: begin
            {hi, out3} = {32'h0, res8};
            overflow = 0;
        end
        4'd9: begin
            {hi, out3} = {32'h0, res9};
            overflow = 0;
        end
        4'd10: begin
            {hi, out3} = {32'h0, res10};
            overflow = 0;
        end
        4'd11: begin
            {hi, out3} = {32'h0, res11};
            overflow = 0;
        end
        4'd12: begin
            {hi, out3} = {32'h0, res12};
            overflow = 0;
        end
        4'd13: begin
            {hi, out3} = {32'h0, res13};
            overflow = 0;
        end
        4'd14: begin
            {hi, out3} = res14;
            overflow = 0;
        end
        default: begin
            {hi, out3} = 64'h0;
            overflow = 0;
        end
    endcase
end
*/
endmodule
