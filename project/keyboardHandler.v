// This is the keyboard module (MYS).

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
	output	newKey,
	output	isASCIIkey,
	output	[7:0]	ASCII
);

//=======================================================
//  REG/WIRE declarations
//=======================================================

// ASCII的LUT
(* ram_init_file = "init_files/scancode.mif" *) reg [7:0] lookupTable [255:0];

wire [7:0] data;
wire ready;
wire [7:0] ASCII_helper;			// raw的ASCII值，不经过shift和Capslock加工
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

//=======================================================
//  Output wire assigning
//=======================================================

assign shift = state[18] | state[89];
assign ctrl =  state[20] | state_E0[20];
assign alt =   state[17] | state_E0[17];
assign capslock = state[88] | capslockflag;
assign insert = state_E0[112] | insertflag;
assign newKey = buffer_newkey[2];
assign ASCII_helper = (
	(scanCode != 0) ? 
	lookupTable[scanCode] :
	8'h2F		// 右边小键盘的斜杠
);
assign ASCII = (
	(shift && scanCode != 0) ?
	shiftCase(ASCII_helper, capslock) :
	(
		(capslock == 1) ?
		capslockCase(ASCII_helper) :
		ASCII_helper
	)
);
assign isASCIIkey = (
	(scanCode != 8'h00 && 
	scanCode	!= 8'h0D && // TAB
	scanCode	!= 8'h76 && // ESC
	scanCode	!= 8'h58 && // CapsLock
	scanCode	!= 8'h12 && // LShift
	scanCode	!= 8'h14 && // LCtrl
	scanCode	!= 8'h11 && // LAlt
	scanCode	!= 8'h59 && // RShift
	scanCode	!= 8'h66 && // 退格键
	scanCode	!= 8'h5A && // LEnter
	scanCode	!= 8'h7E && // Scr LK
	((scanCode > 8'h0C && scanCode != 8'h78) || scanCode == 8'h08)) || // F1~F12
	(scanCode_E0 == 8'h4A) // 右边的除号是，其他的E0开头的都不是
);


//=======================================================
//  Functions
//=======================================================

function [7:0] shiftCase;
	input [7:0] rawCase;
	input capslock;
	if (rawCase >= 8'h61 && rawCase <= 8'h7A)
		if (capslock == 0)
			shiftCase = rawCase - 8'h20;
		else
			shiftCase = rawCase;
	case (rawCase)  // 符号表
		8'h60: shiftCase = 8'h7E; 8'h31: shiftCase = 8'h21; 8'h32: shiftCase = 8'h40;
		8'h33: shiftCase = 8'h23; 8'h34: shiftCase = 8'h24; 8'h35: shiftCase = 8'h25;
		8'h36: shiftCase = 8'h5E; 8'h37: shiftCase = 8'h26; 8'h38: shiftCase = 8'h2A;
		8'h39: shiftCase = 8'h28; 8'h30: shiftCase = 8'h29; 8'h2D: shiftCase = 8'h5F;
		8'h3D: shiftCase = 8'h2B; 8'h5C: shiftCase = 8'h7C; 8'h5B: shiftCase = 8'h7B;
		8'h5D: shiftCase = 8'h7D; 8'h3B: shiftCase = 8'h3A; 8'h27: shiftCase = 8'h22;
		8'h2C: shiftCase = 8'h3C; 8'h2E: shiftCase = 8'h3E; 8'h2F: shiftCase = 8'h3F;
	endcase
endfunction

function [7:0] capslockCase;
	input [7:0] rawCase;
	if (rawCase >= 8'h61 && rawCase <= 8'h7A)
		capslockCase = rawCase - 8'h20;
	else
		capslockCase = rawCase;
endfunction

endmodule
