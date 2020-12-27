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
	output	ESC_n,
	output	ENTER_n,
	output	newKey,
	output	isASCIIkey,
	output	[7:0]	ASCII,
	
	///////// Audio //////////
	output	reg	[15:0]	freq1,
	output	reg	[15:0]	freq2,
	output	reg	[3:0]		volume_ten,
	output	reg	[3:0]		volume_d,
	output	reg	[8:0]		volume,
	input		audio_ena
);

//=======================================================
//  REG/WIRE declarations
//=======================================================

// ASCII的LUT
wire [7:0] LUT_ASCII;
lookupTable LUT(
	.address(scanCode),
	.clock(clk),
	.q(LUT_ASCII)
);

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


///////// For Audio ////////////
reg [7:0] tag_freq1;
reg [7:0] tag_freq2;

initial begin
	freq1 = 0;
	freq2 = 0;
	tag_freq1 = 0;
	tag_freq2 = 0;
	volume_ten = 3;
	volume_d = 0;
	volume = 77;
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
			if (data == 8'hE0) begin
				preE0 <= 1;
				breaking <= 0;
				buffer_newkey <= {buffer_newkey[1:0], 1'b0};
			end else if (data == 8'hF0) begin
				// 改变状态
				breaking <= 1;
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
//////////////// For Audio ///////////////////////////////////////////
						if (audio_ena) begin
							if (keyIndex(data) < 10) begin			  // 不是无关键
								if (tag_freq1 == data) begin
									tag_freq1 <= 0;
									freq1 <= 0;
								end else if (tag_freq2 == data) begin
									tag_freq2 <= 0;
									freq2 <= 0;
								end
							end
						end
//////////////////////////////////////////////////////////////////////
					end
				end else begin
					if (preE0) begin			// 前一个是E0
						preE0 <= 0;
						state_E0[data] <= 1;
						scanCode_E0 <= data;
						scanCode <= 0;
						buffer_newkey <= {buffer_newkey[1:0], 1'b1};
					end else begin
						// 从InitX到X
						state[data] <= 1;
						scanCode <= data;
						scanCode_E0 <= 0;
						buffer_newkey <= {buffer_newkey[1:0], 1'b1};
						
/////////////////////// For Audio /////////////////////////////////
						if (audio_ena) begin
							if (keyIndex(data) == 8) begin
								if (volume_ten < 8) begin // 音量加，上限80
									volume <= volume + 1;
									if (volume_d < 9)
										volume_d <= volume_d + 1;
									else begin
										volume_ten <= volume_ten + 1;
										volume_d <= 0;
									end
								end
							end else
							if (keyIndex(data) == 9) begin
								if (volume_ten > 0 || volume_d > 0) begin // 音量减，下限0
									volume <= volume - 1;
									if (volume_d > 0)
										volume_d <= volume_d - 1;
									else begin
										volume_ten <= volume_ten - 1;
										volume_d <= 9;
									end
								end
							end else begin
								if (tag_freq1 == 0 && data != tag_freq2) begin
									freq1 <= getFrequent(keyIndex(data));
									tag_freq1 <= data;
								end else if (data != tag_freq1) begin
									freq2 <= getFrequent(keyIndex(data));
									tag_freq2 <= data;
								end
							end
						end
///////////////////////////////////////////////////////////////////
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
assign capslock = capslockflag;
assign insert = insertflag;
assign ESC_n = !state[118];
assign ENTER_n = !(state[90] | state_E0[90]);
assign newKey = buffer_newkey[2];
assign ASCII_helper = (
	(scanCode != 0) ? 
	LUT_ASCII :
	8'h2F		// 右边小键盘的斜杠
);
assign ASCII = (
	(shift && (scanCode != 0)) ?
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
	begin
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
	end
endfunction

function [7:0] capslockCase;
	input [7:0] rawCase;
	begin
	if (rawCase >= 8'h61 && rawCase <= 8'h7A)
		capslockCase = rawCase - 8'h20;
	else
		capslockCase = rawCase;
	end
endfunction

//=======================================================
//  Audio Functions
//=======================================================

function [3:0] keyIndex;
	input [7:0] scanCode;
	case (scanCode)
		8'h16: keyIndex = 8; // 音量加
		8'h1E: keyIndex = 9; // 音量减
		8'h1C: keyIndex = 0; 8'h1B: keyIndex = 1; 8'h23: keyIndex = 2;
		8'h2B: keyIndex = 3; 8'h34: keyIndex = 4; 8'h33: keyIndex = 5;
		8'h3B: keyIndex = 6; 8'h42: keyIndex = 7; default: keyIndex = 10;
	endcase
endfunction

function [15:0] getFrequent;
	input [3:0] index;
	case (index)
		0: getFrequent = 16'h2CA;
		1: getFrequent = 16'h322;
		2: getFrequent = 16'h384;
		3: getFrequent = 16'h3BA;
		4: getFrequent = 16'h42E;
		5: getFrequent = 16'h4B1;
		6: getFrequent = 16'h544;
		7: getFrequent = 16'h594;
		default: getFrequent = 0;
	endcase
endfunction

endmodule
