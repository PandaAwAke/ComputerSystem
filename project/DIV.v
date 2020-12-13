module DIV(
    input clk,
    input [31:0] dividend,
    input [31:0] divisor,
    input div_start,
    output reg div_end,
    output reg [31:0] q,
    output reg [31:0] r
);

initial begin
    div_end = 1'b0;
    q = 32'd0;
    r = 32'd0;
end

reg [2:0] state = 3'b0;

wire [31:0] d_neg = -divisor;

reg [5:0] index;

always @ (posedge clk) begin
    case (state)
        3'd0: begin
            div_end <= 1'b0;
            if (div_start) begin
                state <= 3'd1;
                r <= {31'd0, dividend[31]};
                q <= {dividend[30:0], 1'b0};
                index <= 6'd0;
                //div_end <= 1'b0;
            end
        end
        3'd1: begin
            r <= r + d_neg;
            state <= 3'd2;
        end
        3'd2: begin
            if (r[31] == 1'b1) begin
                q[0] <= 1'b0;
                r <= r + divisor;
            end
            else
                q[0] <= 1'b1;
            state <= 3'd3;
            index <= index + 6'd1;
        end
        3'd3: begin
            if (index == 6'd32) begin
                state <= 3'd0;
                div_end <= 1'b1;
            end
            else begin
                r <= {r[30:0], q[31]};
                q <= {q[30:0], 1'b0};
                state <= 3'd1;
            end
        end
    endcase
end

endmodule
