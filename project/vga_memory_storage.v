module videoMemoryStorage(
	input clk,
	
	// 字符显示文件
	input [11:0] vm_index,
	input [11:0] vm_index_header,
	output [11:0] line,
	output [11:0] line_header,
	
	// reg_keysX 和 reg_keysY
	input		[9:0] h_addr,
	input		[9:0] v_addr,
	output	[7:0] keysX,
	output	[7:0] keysY,
	
	// baseX 和 baseY
	output	[11:0] baseX_out,
	output	[11:0] baseY_out,
	
	// keys_base
	output	[11:0] keys_base_out,
	
	// ASCII_base
	input		[7:0] showASCII,
	output	[11:0] ASCII_base_out1,
	output	[11:0] ASCII_base_out2
);

// 读写存储器
vga_memory vMemoryROM(
	.address_a(vm_index),
	.address_b(vm_index_header),
	.clock(clk),
	.q_a(line),
	.q_b(line_header)
);
reg_keysX KeysXROM(
	.address(h_addr),
	.clock(clk),
	.q(keysX)
);
reg_keysY KeysYROM(
	.address(v_addr),
	.clock(clk),
	.q(keysY)
);
baseX baseXROM(
	.address(h_addr),
	.clock(clk),
	.q(baseX_out)
);
baseY baseYROM(
	.address(v_addr),
	.clock(clk),
	.q(baseY_out)
);
keys_base keys_baseROM(
	.address(keysY),
	.clock(clk),
	.q(keys_base_out)
);
ASCII_base ASCII_baseROM(
	.address_a(showASCII),
	.address_b(Header(keysX)),
	.clock(clk),
	.q_a(ASCII_base_out1),
	.q_b(ASCII_base_out2)
);


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
