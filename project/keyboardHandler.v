module keyboardHandler(
	//////////// CLK //////////
	input 	clk,
	input		clrn,
	
	//////////// PS2 //////////
	inout		PS2_CLK,
	inout		PS2_DAT,
	
	//////////// output //////////
	output	reg	[7:0] scanCode,
	output	reg	[7:0] scanCode_E0,
	output	shift,
	output	ctrl,
	output	alt,
	output	capslock,
	output	insert,
	output	newKey
);

//=======================================================
//  REG/WIRE declarations
//=======================================================

wire [7:0] data;
wire ready;
reg nextdata_n;
reg [255:0] state;
reg [255:0] state_E0;
reg breaking;
reg preE0;
reg capslockflag;
reg insertflag;
reg [2:0] buffer_newkey;

initial begin
	// output initialization
	scanCode = 0;
	scanCode_E0 = 0;
	
	// reg initialization
	nextdata_n = 1;
	state = 0;
	breaking = 0;
	preE0 = 0;
	capslockflag = 0;
	insertflag = 0;
	buffer_newkey = 0;
end

//=======================================================
//  Structural coding
//=======================================================

ps2_keyboard inputer(
	.clk(clk),
	.clrn(clrn),
	.ps2_clk(PS2_CLK),
	.ps2_data(PS2_DAT),
	.data(data),
	.ready(ready),
	.nextdata_n(nextdata_n)
);

//=======================================================
//  Clock Logical coding
//=======================================================

always @(posedge clk) begin
	if (nextdata_n == 0) begin	// 让nextdata_n保持一个周期的0
		nextdata_n <= 1;
		buffer_newkey <= {buffer_newkey[1:0], 1'b0};
	end else
		if (ready) begin
			if (data == 8'hF0) begin
				// 改变状态
				breaking <= 1;
				preE0 <= 0;
				buffer_newkey <= {buffer_newkey[1:0], 1'b0};
			end else if (data == 8'hE0) begin
				preE0 <= 1;
				buffer_newkey <= {buffer_newkey[1:0], 1'b0};
			end else begin
				// 要么从InitX到X，要么从breakX到InitX
				if (breaking) begin			// 接收到F0
					if (preE0) begin			// 也接收过E0
						// 这里接受F0 E0后的那个扫描码
						if (data == 8'h70) begin // Insert模式
							insertflag <= ~insertflag;
						end
						breaking <= 0;
						preE0 <= 0;
						state_E0[data] <= 0;
						scanCode_E0 <= 0;
						buffer_newkey <= {buffer_newkey[1:0], 1'b0};
					end else begin				// 只接收到F0，没接收到E0
						// 从breakX到InitX
						if (data == 8'h58) begin // 大写锁定
							capslockflag <= ~capslockflag;
						end
						breaking <= 0;
						state[data] <= 0;
						scanCode <= 0;
						buffer_newkey <= {buffer_newkey[1:0], 1'b0};
					end
				end else begin
					if (preE0) begin			// 前一个是E0
						preE0 <= 0;
						state_E0[data] <= 1;
						scanCode_E0 <= data;
						buffer_newkey <= {buffer_newkey[1:0], 1'b1};
					end else begin
						// 从InitX到X
						state[data] <= 1;
						scanCode <= data;
						buffer_newkey <= {buffer_newkey[1:0], 1'b1};
					end
				end
			end
			nextdata_n <= 0;
		end else
			buffer_newkey <= {buffer_newkey[1:0], 1'b0};
end

assign shift = state[18] | state[89];
assign ctrl = state[20];					// Only left ctrl
assign alt = state[17];						// Only left alt
assign capslock = state[88] | capslockflag;
assign ins = state_E0[112] | insertflag;
assign newKey = buffer_newkey[2];

endmodule
