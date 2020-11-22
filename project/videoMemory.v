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
	input		ASCII,		// 实际显示的ASCII值
	input		isASCIIkey	// 扫描码是否是ASCII字符
);

//=======================================================
//  PARAMETER/REG/WIRE declarations
//=======================================================

parameter BASH_HEAD_LEN = 9;
// 只读存储器
reg [7:0] reg_keysX [639:0];		// h_addr对应的键X是多少 (0~69)
reg [7:0] reg_keysY [479:0];		// v_addr对应的键Y是多少 (0~29)
reg [11:0] keys_base [29:0];		// 第Y行字符对应的keys数组起始坐标
reg [7:0] baseX [639:0];			// h_addr处的字符的起始值，如0~8对应0，9~17对应9
reg [7:0] baseY [479:0];			// v_addr处的字符的起始值
reg [11:0] ASCII_base [255:0];	// ASCII字符对应的vga_memory的基准位置

// 读写存储器
reg [11:0] vga_memory [4095:0];	// 字符显示存储器
reg [7:0] keys [4199:0];			// 最多存入4200个ASCII码

// 控制变量
reg [7:0] roll_cnt_lines;			// 滚屏滚掉多少行
reg [11:0] roll_cnt;					// 滚屏滚掉的下标
reg [11:0] cursor;					// 光标，取值范围：0~2100
reg [7:0] x_cnt;						// 当前水平方向已经有多少个字符，范围0~69
reg [7:0] y_cnt;						// 当前竖直方向已经有多少行，范围0~29
reg [7:0] y_real;						// 实际显示的行，是y_cnt + roll_cnt_lines
reg [7:0] row_tail [59:0];			// 记录每一行的行末位置
reg [59:0] enter;						// 记录这一行是否为回车产生的

// wire计算变量
wire cursor_en;						// 光标使能端
wire [7:0] keysX;
wire [7:0] keysY;
wire [11:0] keys_index;				// 在 (h_addr, v_addr) 处应该显示的 ASCII 字符
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


initial begin
	$readmemh("init_files/VGA_RAM.txt", vga_memory, 0, 4095);
	$readmemh("init_files/zeroKeys.txt", keys, 0, 4199);
	$readmemh("init_files/reg_keysX.txt", reg_keysX, 0, 639);
	$readmemh("init_files/reg_keysY.txt", reg_keysY, 0, 479);
	$readmemh("init_files/keys_base.txt", keys_base, 0, 29);
	$readmemh("init_files/baseX.txt", baseX, 0, 639);
	$readmemh("init_files/baseY.txt", baseY, 0, 479);
	$readmemh("init_files/ASCII_base.txt", ASCII_base, 0, 255);
	cursor = BASH_HEAD_LEN;
	x_cnt = BASH_HEAD_LEN;
	y_cnt = 0;
	roll_cnt_lines = 0;
	roll_cnt = 0;
	enter = 1;
end


//=======================================================
//  Structural coding
//=======================================================

// 光标显示使能端部分开始
clkgen #(2) cursorclk(
	.clkin(clk), 
	.rst(0), 
	.clken(1), 
	.clkout(cursor_en)
);
// 光标显示使能端部分结束

//=======================================================
//  Wire Logical coding
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

//=======================================================
//  Clock Logical coding
//=======================================================

// 显示逻辑
always @(posedge clk) begin
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
end

// 新按键逻辑
always @(posedge newKey) begin
	if (scanCode == 8'h66 && cursor > 0) begin 	// 退格键
		keys[cursor - 1] = 0;
		// 处理x_cnt和y_cnt
		if (enter[y_cnt] && x_cnt == BASH_HEAD_LEN) begin	// 命令提示符回到上一行逻辑
			if (y_cnt > 0) begin
				x_cnt <= row_tail[y_cnt - 1];
				y_cnt <= y_cnt - 1;
				cursor <= cursor + row_tail[y_cnt - 1] - 70 - BASH_HEAD_LEN;
				row_tail[y_cnt] <= 0;
				enter[y_cnt] <= 0;
				if (roll_cnt_lines > 0) begin
					roll_cnt <= roll_cnt - 70;
					roll_cnt_lines <= roll_cnt_lines - 1;
				end
			end
		end else if (x_cnt == 0) begin			// 回到上一行逻辑(这一行无命令提示符)
			if (y_cnt > 0) begin
				x_cnt <= row_tail[y_cnt - 1];
				y_cnt <= y_cnt - 1;
				cursor <= cursor + row_tail[y_cnt - 1] - 70;
				row_tail[y_cnt] <= 0;
				enter[y_cnt] <= 0;
				if (roll_cnt_lines > 0) begin
					roll_cnt <= roll_cnt - 70;
					roll_cnt_lines <= roll_cnt_lines - 1;
				end
			end
		end else begin									// 普通退格逻辑
			x_cnt <= x_cnt - 1;
			cursor <= cursor - 1;
			row_tail[y_cnt] <= x_cnt - 1;
		end
	end else if (scanCode == 8'h5A || scanCode_E0 == 8'h5A) begin			// 回车键
		y_cnt <= y_cnt + 1;
		x_cnt <= BASH_HEAD_LEN;
		cursor <= cursor + (70 + BASH_HEAD_LEN - x_cnt);
		row_tail[y_cnt] <= x_cnt;
		enter[y_cnt + 1] <= 1;
		if (y_cnt >= 28) begin		// 28行后自动滚屏
			roll_cnt <= roll_cnt + 70;
			roll_cnt_lines <= roll_cnt_lines + 1;
		end
	end else if (scanCode != 8'h66 && isASCIIkey) begin	// 其他正常字符键
		keys[cursor] = ASCII;
		cursor <= cursor + 1;
		// 处理x_cnt和y_cnt
		if (x_cnt == 69) begin
			y_cnt <= y_cnt + 1;
			x_cnt <= 0;
			row_tail[y_cnt] <= 69;
			if (y_cnt >= 28) begin		// 28行后自动滚屏
				roll_cnt <= roll_cnt + 70;
				roll_cnt_lines <= roll_cnt_lines + 1;
			end
		end else begin
			x_cnt <= x_cnt + 1;
			row_tail[y_cnt] <= x_cnt + 1;
		end
	end
end



//=======================================================
//  Functions
//=======================================================

function [7:0] Header;  // 命令提示符内容
	input [7:0] index;
	case (index)
		0: Header = 8'h6D;
		1: Header = 8'h79;
		2: Header = 8'h73;
		3: Header = 8'h62;
		4: Header = 8'h61;
		5: Header = 8'h73;
		6: Header = 8'h68;
		7: Header = 8'h24;
		8: Header = 8'h20;
		default: Header = 0;
	endcase
endfunction

endmodule
