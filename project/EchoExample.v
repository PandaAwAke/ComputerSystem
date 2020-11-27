// This is an example interact (echo mode) with bash I/O.
// Written by MYS, 2020.11.23.

module EchoExample(
	//////////// CLK ////////////
	input		clk,
	//////////// Video Memory : Solved Signal ///////////
	// 下面的 In, Out 应该看作显存处理视角的
	output	reg	in_solved,				// 结束信号，解决完这条指令后传递1一个周期
	input				out_solved,				// 显存模块处理完结束信号会输出1一个周期进来
	
	// 向屏幕输出信息，外部模块应该注意最后一位是00
	input				lineIn_nextASCII,				
	output	reg	in_newASCII_ready,	// 没输出完这一行就给1
	output	[7:0]	lineIn,					// 输出的字符，字符串以00结尾
	
	// 读取bash输入信息，注意读入的长度不超过32且最后一位是00
	output	reg	lineOut_nextASCII,	// 读好一个字符之后应该传递1一个周期
	input				out_newASCII_ready,	// 这一行还没传递完就是1
	input		[5:0] out_lineLen,			// 约定合法的一行最长32字符，值为实际长度
	input		[7:0]	lineOut					// 接收的字符
	////////// TEST /////////////
	//output   reg	[5:0] echo_len_help
);


initial begin
	// output
	in_solved = 0;
	in_newASCII_ready = 0;
	lineOut_nextASCII = 0;
	
	
end


reg [7:0] buffer [31:0];
reg [5:0] echo_len_help;	// 读取屏幕输入用的循环变量，也是读入的实际长度
reg [5:0] echo_len_help2;	// 输出屏幕用的循环变量2，要从0循环到echo_len_help
reg received;					// 是否接收到了屏幕输入

// 是否允许输出，在读屏幕输入的时候应该不能输出，此值为1才有资格输出
// 可以改
wire output_valid = !out_newASCII_ready;

// REGISTERS INITIALIZATION
initial begin
	echo_len_help = 0;
	echo_len_help2 = 0;
	received = 0;
end

always @(posedge clk) begin
	// 从屏幕读入
	if (lineOut_nextASCII) begin
		lineOut_nextASCII <= 0;
	end else if (out_newASCII_ready) begin
		// 存入缓冲区，最后一位00不存
		lineOut_nextASCII <= 1;
		if (lineOut == 0) begin
			// 读取结束，可以添加代码
			received <= 1;
		end else begin
			echo_len_help <= echo_len_help + 1;
			buffer[echo_len_help] <= lineOut;
		end
	end
	
	// 向屏幕输出，处理这个模块的ready信号
	if (output_valid)
		if (out_solved)
			in_solved <= 0;
		else if (in_newASCII_ready) begin
			if (echo_len_help2 == echo_len_help) begin	// 相等，到头了，结束输出（可以改）
				in_solved <= 1;
				in_newASCII_ready <= 0;
				// Clear操作
				echo_len_help  <= 0;
				echo_len_help2 <= 0;
			end else if (lineIn_nextASCII)
				echo_len_help2 <= echo_len_help2 + 1;
		end
	
	
	// 读取完屏幕输入，输出ready信号
	// 可以改
	if (output_valid && received) begin
		in_newASCII_ready <= 1;
		received <= 0;
		echo_len_help2 <= 0;
	end
end


assign lineIn = (
	(echo_len_help2 == echo_len_help) ?
	0 :
	buffer[echo_len_help2]
);



endmodule
