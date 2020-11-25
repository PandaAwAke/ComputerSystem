// This is the bash I/O main module (MYS).

module videoMemory(
	//////////// CLK //////////
	input		clk,
	
	//////////// VGA //////////
	input		[9:0] h_addr,
	input		[9:0] v_addr,
	output	reg	[11:0] rgb,
	
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
	input				in_solved,						// 结束信号，解决完这条指令后传递1一个周期进这个模块
	output	reg	out_solved,						// 本模块处理完结束信号会输出1一个周期
	
	// 外界模块输入bash输出信息，外部模块应该注意最后一位是00
	output	reg	lineIn_nextASCII,
	input				in_newASCII_ready,			// 这一行的ready，这一行结束时应该为0
	input				[7:0]		lineIn,				// 输入，最长64字符，应该按照in_lineLen取
	
	// 向外界模块输出bash输入信息，外部模块应该注意最后一位是00
	input				lineOut_nextASCII,			// 外界模块读好一个字符之后应该传递1进来一个周期
	output	reg	out_newASCII_ready,	
	output	reg	[5:0] 	out_lineLen,		// 约定合法的一行最长32字符+00结束，值为实际长度
	output			[7:0]		lineOut				// 输出，一个一个输出
);

initial begin
	// output
	out_solved = 0;
	out_newASCII_ready = 0;
	out_lineLen = 0;
	lineIn_nextASCII = 0;
	rgb = 0;
end

//=======================================================
//  PARAMETER/REG/WIRE declarations
//=======================================================

parameter BASH_HEAD_LEN = 9;
// 只读存储器
reg [7:0] reg_keysX [639:0];		// h_addr对应的键X是多少 (0~69)
reg [7:0] reg_keysY [479:0];		// v_addr对应的键Y是多少 (0~29)
reg [11:0] keys_base [29:0];		// 第Y行字符对应的keys数组起始坐标
reg [11:0] baseX [639:0];			// h_addr处的字符的起始值，如0~8对应0，9~17对应9
reg [11:0] baseY [479:0];			// v_addr处的字符的起始值
reg [11:0] ASCII_base [255:0];	// ASCII字符对应的vga_memory的基准位置

// 读写存储器
reg [11:0] vga_memory [4095:0];	// 字符显示存储器
reg [7:0] keys [4199:0];			// 最多存入4200个ASCII码

// wire计算变量
wire [7:0] keysX;
wire [7:0] keysY;
wire [12:0] keys_index;				// 在 (h_addr, v_addr) 处应该显示的 ASCII 字符
wire [7:0] showASCII;				// 应该显示的ASCII位置下标

// 显示位置
wire [7:0] offsetX;
wire [7:0] offsetY;

wire [11:0] vm_index;
wire [11:0] line;
wire [11:0] showcolor;

// 命令提示符
wire [11:0] vm_index_header;
wire [11:0] line_header;
wire [11:0] showcolor_header;

// 滚屏记录
reg [7:0] roll_cnt_lines;			// 滚屏滚掉多少行
reg [12:0] roll_cnt;					// 滚屏滚掉的下标

initial begin
	$readmemh("init_files/VGA_RAM.txt", vga_memory, 0, 4095);
	$readmemh("init_files/zeroKeys.txt", keys, 0, 4199);
	$readmemh("init_files/reg_keysX.txt", reg_keysX, 0, 639);
	$readmemh("init_files/reg_keysY.txt", reg_keysY, 0, 479);
	$readmemh("init_files/keys_base.txt", keys_base, 0, 29);
	$readmemh("init_files/baseX.txt", baseX, 0, 639);
	$readmemh("init_files/baseY.txt", baseY, 0, 479);
	$readmemh("init_files/ASCII_base.txt", ASCII_base, 0, 255);
end


//=======================================================
//  Structural Coding
//=======================================================

wire cursor_en;						// 光标使能端
// 光标显示使能端部分开始
clkgen #(2) cursorclk(
	.clkin(clk), 
	.rst(0), 
	.clken(1), 
	.clkout(cursor_en)
);
// 光标显示使能端部分结束

//=======================================================
//  Wire Logical Coding
//=======================================================

assign keysX = reg_keysX[h_addr];
assign keysY = reg_keysY[v_addr];
assign keys_index = roll_cnt + keys_base[keysY] + keysX;
// 在 (h_addr, v_addr) 处应该显示的 ASCII 字符
assign showASCII = keys[keys_index];

// 应该显示的ASCII位置
assign offsetX = h_addr - baseX[h_addr];
assign offsetY = v_addr - baseY[v_addr];

assign vm_index = ASCII_base[showASCII] + offsetY;
assign line = vga_memory[vm_index];
assign showcolor = line[offsetX] ? 12'hFFF : 12'h0;
// 命令提示符
assign vm_index_header = ASCII_base[Header(keysX)] + offsetY;
assign line_header = vga_memory[vm_index_header];
assign showcolor_header = line_header[offsetX] ? 12'hFFF : 12'h0;

// 输出
assign lineOut = (
	(out_lineLen_help == out_lineLen) ?
	0 :
	buffer[out_lineLen_help]
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



//=======================================================
//  Keyboard Handling Coding
//=======================================================

// 控制变量
reg [12:0] cursor;					// 光标，取值范围：0~2100
reg [7:0] x_cnt;						// 当前水平方向已经有多少个字符，范围0~69
reg [7:0] y_cnt;						// 当前竖直方向已经有多少行，范围0~59
reg [59:0] enter;						// 记录这一行是否为回车产生的

reg [5:0] out_lineLen_help;		// 向外输出长度的辅助变量
reg [7:0] buffer 	[31:0];

reg ROLL_CLEAR_FIRST_LINE;			// 滚屏太多清除第一行
reg [12:0] ROLL_CLEAR_ITER;		// 滚屏清除第一行用的循环变量


reg keyboard_valid;					// 是否接受键盘消息，外界模块在处理一条指令时这个应该是0
reg output_flag;						// 这个时钟周期应该开始输出数据，是为了和57行清屏配合的

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
	//in_lineLen_help = 0;
	
	
	keyboard_valid = 1;
end


// Cashing, 防止织毛衣
// 防止织毛衣，下一个周期再去存储器存
//////////// keys ////////////
reg [12:0]	keys_index_helper = 0;		// keys的下标
reg 			flag_keys_write = 0;			// 写入flag标记，为1则写入
reg [7:0] 	keys_ASCII_help = 0;			// 写入内容

// 主要逻辑块
always @(posedge clk) begin
	if (ROLL_CLEAR_FIRST_LINE)
		rgb <= rgb;
	else
		if (h_addr >= 630) begin
			rgb <= 12'h0;
		end else if (keys_index == cursor && cursor_en) begin // 光标部分
			if (offsetY < 13)  // 光标高度为3(/16)
				rgb <= showcolor;
			else
				rgb <= 12'hFFF;
		end else if (enter[keysY + roll_cnt_lines] && keysX < BASH_HEAD_LEN) begin	// 命令提示符
			rgb <= showcolor_header;
		end else begin	// 正常部分
			rgb <= showcolor;
		end
	
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
	// 回车的下个周期：开始往外送数据，因为考虑到可能会引起57行之后的清空操作，所以隔一个周期处理
	if (output_flag) begin
		output_flag <= 0;
		out_lineLen <= out_lineLen_help;
		out_lineLen_help <= 0;
		out_newASCII_ready <= 1;				// 空行也必须向外传递，否则无法完成处理
		keyboard_valid <= 0;
	end else
	begin									// 不缩进了

	
	// Cashing-keys
	if (flag_keys_write) begin					// 缓存机制：keys在下一个周期进行存储
		keys[keys_index_helper] <= keys_ASCII_help;
		keys_index_helper <= 0;
		flag_keys_write <= 0;
		keys_ASCII_help <= 0;
	end
	
	
	if (out_solved)
		out_solved <= 0;
	else if (!keyboard_valid && in_solved) begin
		// 解决这条指令，恢复输入模式
		keyboard_valid <= 1;
		x_cnt <= BASH_HEAD_LEN;
		cursor <= cursor + BASH_HEAD_LEN;
		out_solved <= 1;
		enter[y_cnt] <= 1; 	// 新的命令提示符
	end
	
	
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

	
	
	
	// 新按键逻辑
	if (sampling_newKey && keyboard_valid) begin
		// 新键处理开始
		if (scanCode == 8'h66 && cursor > 0) begin 				// 退格键，有格可退
			
			// keys[cursor - 1] <= 0;
			// 防止织毛衣，交给下个周期做
			flag_keys_write <= 1;
			keys_index_helper <= cursor - 1;
			keys_ASCII_help <= 0;
			
			// 处理x_cnt和y_cnt
			if (enter[y_cnt] && x_cnt == BASH_HEAD_LEN) begin	// 命令提示符到头了
				out_lineLen_help <= 0;
			end else if (x_cnt == 0) begin							// 回到上一行逻辑(这一行无命令提示符)
				if (y_cnt > 0) begin
					out_lineLen_help <= out_lineLen_help - 1;
					x_cnt <= 69;
					y_cnt <= y_cnt - 1;
					cursor <= cursor - 1;
					
					enter[y_cnt] <= 0;
					if (roll_cnt_lines > 0) begin
						roll_cnt <= roll_cnt - 70;
						roll_cnt_lines <= roll_cnt_lines - 1;
					end
				end else begin
					out_lineLen_help <= out_lineLen_help - 1;
				end
			end else begin													// 普通退格逻辑
				out_lineLen_help <= out_lineLen_help - 1;
				x_cnt <= x_cnt - 1;
				cursor <= cursor - 1;
			end
		end else if (scanCode == 8'h5A || scanCode_E0 == 8'h5A) begin	// 回车键
			output_flag <= 1;
			
			y_cnt <= y_cnt + 1;
			x_cnt <= 0;
			cursor <= cursor + (70 - x_cnt);
			ROLL_CLEAR_FIRST_LINE <= (y_cnt >= 56);
			
			if (y_cnt >= 27) begin										// 27行后自动滚屏
				roll_cnt <= roll_cnt + 70;
				roll_cnt_lines <= roll_cnt_lines + 1;
			end
			
			
		end else if (scanCode != 8'h66 && isASCIIkey) begin	// 其他正常字符键
			if (out_lineLen_help < 32) begin						// 维护输出字符串
				out_lineLen_help <= out_lineLen_help + 1;
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



//=======================================================
//  Functions
//=======================================================

function [7:0] Header;  // 命令提示符内容: SSshell
	input [7:0] index;
	case (index)
		0: Header = 8'h53;
		1: Header = 8'h53;
		2: Header = 8'h73;
		3: Header = 8'h68;
		4: Header = 8'h65;
		5: Header = 8'h6C;
		6: Header = 8'h6C;
		7: Header = 8'h24;
		8: Header = 8'h20;
		default: Header = 0;
	endcase
endfunction

endmodule
