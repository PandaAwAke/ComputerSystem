// This is a module for videoMemory.v to use.
// Assign all wire variables.

module videoMemory_assign(
// INPUTS
	input		[12:0]	roll_cnt,
	input		[11:0]	keys_base_out,
	input		[7:0]		keysX,
	input		[9:0]		h_addr,
	input		[11:0]	baseX_out,
	input		[9:0]		v_addr,
	input		[11:0]	baseY_out,
	input		[11:0]	ASCII_base_out1,
	input		[11:0]	ASCII_base_out2,
	input		[11:0]	line,
	input		[11:0]	line_header,
	input		[7:0]		scanCode_E0,
	input		[23:0]	color_background,
	input		[23:0]	color_text,
	
// OUTPUTS
	output	[12:0]	keys_index,
	output	[7:0]		offsetX,
	output	[7:0]		offsetY,
	output	[11:0]	vm_index,
	output	[23:0]	showcolor,
	output	[11:0]	vm_index_header,
	output	[23:0]	showcolor_header,
	output				direction_flag
);

assign keys_index = roll_cnt + keys_base_out + keysX;
// 应该显示的ASCII位置
assign offsetX = h_addr - baseX_out;
assign offsetY = v_addr - baseY_out;
assign vm_index = ASCII_base_out1 + offsetY;
assign showcolor = line[offsetX] ? color_text : color_background;
// 命令提示符
assign vm_index_header = ASCII_base_out2 + offsetY;
assign showcolor_header = line_header[offsetX] ? color_text : color_background;
// 方向键标志
assign direction_flag = (
	scanCode_E0 == 8'h75 || scanCode_E0 == 8'h72 || scanCode_E0 == 8'h74 || scanCode_E0 == 8'h6B
);


endmodule
