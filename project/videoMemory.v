// This is the bash I/O main module (MYS).

module videoMemory(
	//////////// CLK //////////
	input		clk,
	
	//////////// VGA //////////
	input		[9:0] h_addr,
	input		[9:0] v_addr,
	output	reg	[23:0] rgb,
	
	//////////// KBHandler //////////
	input		[7:0] scanCode,
	input		[7:0] scanCode_E0,
	input		shift,
	input		ctrl,
	input		alt,
	input		capslock,
	input		insert,
	input		newKey,
	input		[7:0]	ASCII,		// 实际显示的ASCII值
	input		isASCIIkey,	// 扫描码是否是ASCII字符
	
	//////////// Interface ///////////
	input				inWelcome,
	
	input				in_solved,						// 结束信号，解决完这条指令后传递1一个周期进这个模块
	output	reg	out_solved,						// 本模块处理完结束信号会输出1一个周期
	input				in_require_line,					// 需要输入一行数据
	output	reg	out_require_line,					// 知道了，然后我开始输入（配合滚屏）
	
	// 外界模块输入bash输出信息，外部模块应该注意最后一位是00
	output	reg	lineIn_nextASCII,
	input				in_newASCII_ready,			// 这一行的ready，这一行结束时应该为0
	input				[7:0]		lineIn,				// 输入
	
	// 向外界模块输出bash输入信息，外部模块应该注意最后一位是00
	input				lineOut_nextASCII,			// 外界模块读好一个字符之后应该传递1进来一个周期
	output	reg	out_newASCII_ready,	
	output	reg	[12:0] 	out_lineLen,		// 约定合法的一行最长BUFFER_LEN字符+00结束，值为实际长度
	output			[7:0]		lineOut				// 输出，一个一个输出
);

initial begin
	// output
	out_solved = 1'b0;
	out_newASCII_ready = 1'b0;
	out_lineLen = 13'b0;
	lineIn_nextASCII = 1'b0;
	rgb = 24'b0;
end

//=======================================================
//  PARAMETER declarations
//=======================================================
parameter BASH_HEAD_LEN = 9;
parameter BUFFER_LEN = 128;
//=======================================================
//  Showing Wire & Storage Logical Coding
//=======================================================
// ROMs
wire [11:0] baseX_out;
wire [11:0] baseY_out;
wire [11:0] keys_base_out;
wire [11:0] ASCII_base_out1;
wire [11:0] ASCII_base_out2;

// wire计算变量
wire [7:0] keysX;
wire [7:0] keysY;
wire [12:0] keys_index;		// 在 (h_addr, v_addr) 处应该显示的 ASCII 字符
wire [7:0] showASCII;		// 应该显示的ASCII位置下标

// 显示位置
wire [7:0] offsetX;
wire [7:0] offsetY;
wire [11:0] vm_index;
wire [11:0] line;
wire [23:0] showcolor;

// 命令提示符
wire [11:0] vm_index_header;
wire [11:0] line_header;
wire [23:0] showcolor_header;

// 控制台配色，一共四种，按上下左右键切换
reg  [1:0]	vout_color_iterator;
reg  [23:0]	vout_color_background[3:0];
reg  [23:0]	vout_color_text[3:0];
wire [23:0]	current_vout_color_background = vout_color_background[vout_color_iterator];
wire [23:0]	current_vout_color_text = vout_color_text[vout_color_iterator];

initial begin
	vout_color_iterator = 0; // Default
	// Scheme 1 (Default, Up)
	vout_color_background[0] = 24'h000000;
	vout_color_text[0] = 24'hFFFFFF;
	// Scheme 2 (Right)		(Chocolate)
	vout_color_background[1] = 24'hC1B6A0;
	vout_color_text[1] = 24'h382113;
	// Scheme 3 (Down)		(Blue-White)
	vout_color_background[2] = 24'h027CBD;
	vout_color_text[2] = 24'hFFFFFF;
	// Scheme 4 (Left)		(NJU-Purple)
	vout_color_background[3] = 24'h63065F;
	vout_color_text[3] = 24'hF7F4AD;
end

// 输出总线
assign lineOut = (
	(out_lineLen_help == out_lineLen) ?
	0 :
	buffer[out_lineLen_help]
);

// 在 (h_addr, v_addr) 处应该显示的 ASCII 字符
assign showASCII = keys[keys_index];
videoMemoryStorage vStorage(
	.clk(clk),
// 字符显示文件
	.vm_index(vm_index),
	.vm_index_header(vm_index_header),
	.line(line),
	.line_header(line_header),
// reg_keysX 和 reg_keysY
	.h_addr(h_addr),
	.v_addr(v_addr),
	.keysX(keysX),
	.keysY(keysY),
// baseX 和 baseY
	.baseX_out(baseX_out),
	.baseY_out(baseY_out),
// keys_base
	.keys_base_out(keys_base_out),
// ASCII_base
	.showASCII(showASCII),
	.ASCII_base_out1(ASCII_base_out1),
	.ASCII_base_out2(ASCII_base_out2)
);

videoMemory_assign vAssign(
// INPUTS
	.roll_cnt(roll_cnt),
	.keys_base_out(keys_base_out),
	.keysX(keysX),
	.h_addr(h_addr),
	.baseX_out(baseX_out),
	.v_addr(v_addr),
	.baseY_out(baseY_out),
	.ASCII_base_out1(ASCII_base_out1),
	.ASCII_base_out2(ASCII_base_out2),
	.line(line),
	.line_header(line_header),
	.scanCode_E0(scanCode_E0),
	.color_background(current_vout_color_background),
	.color_text(current_vout_color_text),
// OUTPUTS
	.keys_index(keys_index),
	.offsetX(offsetX),
	.offsetY(offsetY),
	.vm_index(vm_index),
	.showcolor(showcolor),
	.vm_index_header(vm_index_header),
	.showcolor_header(showcolor_header),
	.direction_flag(direction_flag)
);
// 光标显示使能端
clkgen #(2) cursorclk(
	.clkin(clk), 
	.rst(0), 
	.clken(1), 
	.clkout(cursor_en)
);

//=======================================================
//  Posedge Detector
//=======================================================
reg [2:0] newKey_sync;
wire sampling_newKey = ~newKey_sync[2] & newKey_sync[1];
initial begin
	newKey_sync = 0;
end
always @(posedge clk) begin
	newKey_sync <= {newKey_sync[1:0], newKey};
end

//=======================================================
//  VGA Showing Coding
//=======================================================
// 显示逻辑
always @(negedge clk) begin
	if (ROLL_CLEAR_FIRST_LINE)
		rgb <= rgb;
	else
		if (h_addr >= 630) begin
			rgb <= current_vout_color_background;
		end else if (keys_index == cursor && cursor_en) begin // 光标部分
			if (insert) begin
				if (offsetY < 11)  // Insert模式，光标高度为5(/16)
					rgb <= showcolor;
				else
					rgb <= current_vout_color_text;
			end else begin
				if (offsetY < 13)  // 非Insert模式，光标高度为3(/16)
					rgb <= showcolor;
				else
					rgb <= current_vout_color_text;
			end
		end else if (enter[keysY + roll_cnt_lines] && keysX < BASH_HEAD_LEN) begin	// 命令提示符
			rgb <= showcolor_header;
		end else begin	// 正常部分
			rgb <= showcolor;
		end
end


//=======================================================
//  Controling RAM/REGs Coding
//=======================================================
// keys-RAM
reg [7:0] keys [4199:0];			// 最多存入4200个ASCII码

// 控制变量
// 滚屏记录
reg [7:0]  roll_cnt_lines;			// 滚屏滚掉多少行
reg [12:0] roll_cnt;					// 滚屏滚掉的下标

// 方向键标志
wire direction_flag;
// 光标使能端
wire cursor_en;

reg [12:0] cursor;						// 光标，取值范围：0~2100
reg [7:0] x_cnt;							// 当前水平方向已经有多少个字符，范围0~69
reg [7:0] y_cnt;							// 当前竖直方向已经有多少行，范围0~59
reg [59:0] enter;							// 记录这一行是否为回车产生的

reg [12:0] out_lineLen_help;			// 向外输出长度的辅助变量
reg [7:0] buffer 	[BUFFER_LEN-1 : 0];

reg ROLL_CLEAR_FIRST_LINE;				// 滚屏太多清除第一行
reg [12:0] ROLL_CLEAR_ITER;			// 滚屏清除第一行用的循环变量

reg keyboard_valid;						// 是否接受键盘消息，外界模块在处理一条指令时这个应该是0
reg output_flag;							// 这个时钟周期应该开始输出数据，是为了和57行清屏配合的
reg running_program;						// 是否正在运行程序，如果正在运行程序退格时可能是在运行时输入
reg set_running_start_cursor;		// 配合下面一个reg使用
reg [12:0] running_start_cursor;		// 如果在运行程序，而且需要屏幕输入，这时需要记录输入起始光标，防止用户退格到上一行


// REGISTERS INITIALIZATION
initial begin
	roll_cnt_lines = 0;
	roll_cnt = 0;
	cursor = BASH_HEAD_LEN;
	x_cnt = BASH_HEAD_LEN;
	y_cnt = 0;
	enter = 1;
	out_lineLen_help = 0;
	
	ROLL_CLEAR_FIRST_LINE = 0;
	ROLL_CLEAR_ITER = 0;
	
	keyboard_valid = 1;
	output_flag = 0;
	running_program = 0;
	set_running_start_cursor = 0;
	running_start_cursor = 0;
end


// Cashing, 防止织毛衣
// 防止织毛衣，下一个周期再去存储器存
//////////// keys cashing ////////////
reg [12:0]	keys_index_helper = 0;		// keys的下标
reg 			flag_keys_write = 0;			// 写入flag标记，为1则写入
reg [7:0] 	keys_ASCII_help = 0;			// 写入内容

// 主要逻辑块
always @(posedge clk) begin
	///////////////// Screen Rolling Coding /////////////////////
	if (ROLL_CLEAR_FIRST_LINE) begin			// 滚屏到57行了，把后面的行都往上移一行
		if (lineIn_nextASCII)
			lineIn_nextASCII <= 0;
		if (ROLL_CLEAR_ITER == 0) begin
			// 清空第一行的初始化操作
			if (flag_keys_write)
				keys_index_helper <= keys_index_helper - 70;
			cursor <= cursor - 70;
			y_cnt <= y_cnt - 1;
			roll_cnt <= roll_cnt - 70;
			roll_cnt_lines <= roll_cnt_lines - 1;
			running_start_cursor <= running_start_cursor - 70;
		end
		
		if (ROLL_CLEAR_ITER < 57) begin
			enter[ROLL_CLEAR_ITER] <= enter[ROLL_CLEAR_ITER + 1];
		end
		
		if (ROLL_CLEAR_ITER < 3990) begin	// 57 * 70
			ROLL_CLEAR_ITER <= ROLL_CLEAR_ITER + 1;
			keys[ROLL_CLEAR_ITER] <= keys[ROLL_CLEAR_ITER + 70];
		end else begin
			ROLL_CLEAR_FIRST_LINE <= 0;
			ROLL_CLEAR_ITER <= 0;
		end
	end
	else
	///////////////// Start to output lineOut Coding /////////////////////
	// 回车的下个周期：开始往外送数据，因为考虑到可能会引起57行之后的清空操作，所以隔一个周期处理
	if (output_flag) begin
		output_flag <= 0;
		if (out_lineLen_help > BUFFER_LEN)
			out_lineLen <= BUFFER_LEN;
		else
			out_lineLen <= out_lineLen_help;
		out_lineLen_help <= 0;
		out_newASCII_ready <= 1;				// 空行也必须向外传递，否则无法完成处理
		keyboard_valid <= 0;
		running_program <= 1;
	end else
begin
	///////////////// keys cashing /////////////////////
	if (flag_keys_write) begin					// 缓存机制：keys在下一个周期进行存储
		keys[keys_index_helper] <= keys_ASCII_help;
		keys_index_helper <= 0;
		flag_keys_write <= 0;
		keys_ASCII_help <= 0;
	end
	
	///////////////// Finish Output lineOut Coding /////////////////////
	if (out_solved)
		out_solved <= 0;
	else if (!keyboard_valid && in_solved) begin
		// 解决这条指令，恢复输入模式
		keyboard_valid <= 1;
		x_cnt <= BASH_HEAD_LEN;
		cursor <= cursor + BASH_HEAD_LEN;
		out_solved <= 1;
		enter[y_cnt] <= 1; 	// 新的命令提示符
		running_program <= 0;
	end
	
	///////////////// Require new line //////////////////////////
	if (!in_newASCII_ready && in_require_line) begin
		keyboard_valid <= 1;
		out_require_line <= 1;
		set_running_start_cursor <= 1;
	end
	if (set_running_start_cursor) begin		// 下一个周期再去读cursor，这样可以防止各种意外
		set_running_start_cursor <= 0;
		running_start_cursor <= cursor;
	end
	
	if (out_require_line)
		out_require_line <= 0;
	
	///////////////// Output lineOut Coding /////////////////////
	// 屏幕输入，向外界输出逻辑
	if (!keyboard_valid)							// 键盘不能输入才执行，防止与顶层模块交互错误（保险机制）
		if (out_newASCII_ready) begin			// 数据输出逻辑
			if (out_lineLen_help == out_lineLen) begin
				out_newASCII_ready <= 0;
				out_lineLen_help <= 0;
			end else if (lineOut_nextASCII) begin
				out_lineLen_help <= out_lineLen_help + 1;
			end
		end
	
	///////////////// Input lineIn Coding /////////////////////
	// 外界输入，向屏幕输出逻辑
	if (!keyboard_valid)							// 键盘不能输入才执行，防止与顶层模块交互错误（保险机制）
		if (lineIn_nextASCII) begin
			lineIn_nextASCII <= 0;
		end else begin
			if (in_newASCII_ready) begin		// 有数据输入
				lineIn_nextASCII <= 1;
				if (lineIn == 0) begin			// 这行输出完了
					y_cnt <= y_cnt + 1;
					x_cnt <= 0;
					cursor <= cursor + (70 - x_cnt);
					ROLL_CLEAR_FIRST_LINE <= (y_cnt >= 56);
					
					if (y_cnt >= 27) begin										// 27行后自动滚屏
						roll_cnt <= roll_cnt + 70;
						roll_cnt_lines <= roll_cnt_lines + 1;
					end
					
				end else begin
					// 后续输出到屏幕逻辑
					//keys[cursor] <= lineIn;
					flag_keys_write <= 1;
					keys_index_helper <= cursor;
					keys_ASCII_help <= lineIn;
					
					cursor <= cursor + 1;
					// 处理x_cnt和y_cnt
					if (x_cnt == 69) begin
						y_cnt <= y_cnt + 1;
						x_cnt <= 0;
						ROLL_CLEAR_FIRST_LINE <= (y_cnt >= 56);
						
						if (y_cnt >= 27) begin									// 27行后自动滚屏
							roll_cnt <= roll_cnt + 70;
							roll_cnt_lines <= roll_cnt_lines + 1;
						end
					end else begin
						x_cnt <= x_cnt + 1;
					end
				end
			end
		end

	
	///////////////// newKey Coding /////////////////////
	if (sampling_newKey && keyboard_valid && !inWelcome) begin
		// 新键处理开始
		
		///////////////// Backspace /////////////////////
		if (scanCode == 8'h66 && cursor > BASH_HEAD_LEN) begin// 退格键
			// keys[cursor - 1] <= 0;
			// 防止织毛衣，交给下个周期做
			flag_keys_write <= 1;
			keys_index_helper <= cursor - 1;
			keys_ASCII_help <= 0;
			
			// 处理x_cnt和y_cnt
			if (enter[y_cnt] && x_cnt == BASH_HEAD_LEN) begin	// 命令提示符这行到头了
				// Do nothing
				out_lineLen_help <= 0;
			end else if (x_cnt == 0 && (
					(!running_program) || (cursor > running_start_cursor)
					)) begin
				// 回到上一行逻辑(这一行无命令提示符)
				// 要么是没运行程序，要么是程序需要输入
				// 如果程序需要输入，不能在需要输入的地方顶头退格！会把上一行退掉的。
				// 一定有y_cnt > 0，因为第一行是有命令提示符的
				out_lineLen_help <= out_lineLen_help - 1;
				x_cnt <= 69;
				y_cnt <= y_cnt - 1;
				cursor <= cursor - 1;
				if (roll_cnt_lines > 0) begin
					roll_cnt <= roll_cnt - 70;
					roll_cnt_lines <= roll_cnt_lines - 1;
				end
			end else if (
				((!running_program) && (x_cnt > 0)) ||
				((running_program) && (cursor > running_start_cursor))
			) begin								// 普通退格逻辑
				out_lineLen_help <= out_lineLen_help - 1;
				x_cnt <= x_cnt - 1;
				cursor <= cursor - 1;
			end
		end else
		///////////////// Enter /////////////////////
		if (scanCode == 8'h5A || scanCode_E0 == 8'h5A) begin	// 回车键
			output_flag <= 1;
			
			y_cnt <= y_cnt + 1;
			x_cnt <= 0;
			cursor <= cursor + (70 - x_cnt);
			ROLL_CLEAR_FIRST_LINE <= (y_cnt >= 56);
			
			if (y_cnt >= 27) begin										// 27行后自动滚屏
				roll_cnt <= roll_cnt + 70;
				roll_cnt_lines <= roll_cnt_lines + 1;
			end
		end else
		///////////////// Direction Key /////////////////////
		if (direction_flag) begin							// 方向键
			case (scanCode_E0)
				8'h75: begin	// 上
					vout_color_iterator <= 0;
				end
				8'h72: begin	// 下
					vout_color_iterator <= 2;
				end
				8'h6B: begin	// 左
					vout_color_iterator <= 3;
				end
				8'h74: begin	// 右
					vout_color_iterator <= 1;
				end
			endcase
		end else
		///////////////// Other ASCII Key /////////////////////
		if (scanCode != 8'h66 && isASCIIkey) begin	// 其他正常字符键
			out_lineLen_help <= out_lineLen_help + 1;
			if (out_lineLen_help < BUFFER_LEN) begin						// 维护输出字符串
				buffer[out_lineLen_help] <= ASCII;
			end

			//keys[cursor] <= ASCII;
			flag_keys_write <= 1;
			keys_index_helper <= cursor;
			keys_ASCII_help <= ASCII;
			
			cursor <= cursor + 1;
			// 处理x_cnt和y_cnt
			if (x_cnt == 69) begin
				y_cnt <= y_cnt + 1;
				x_cnt <= 0;
				ROLL_CLEAR_FIRST_LINE <= (y_cnt >= 56);
				if (y_cnt >= 27) begin									// 27行后自动滚屏
					roll_cnt <= roll_cnt + 70;
					roll_cnt_lines <= roll_cnt_lines + 1;
				end
			end else begin
				x_cnt <= x_cnt + 1;
			end
		end
		// 新键处理结束
	end
	
end
end
endmodule
