module welcome(
	//////////// CLK //////////
	input		clk,
	
	//////////// VGA //////////
	input		[9:0] h_addr,
	input		[9:0] v_addr,
	output	[23:0] rgb_welcome,
	
	//////////// INTERFACE //////////
	output	reg	inWelcome,
	input		newKey
);


//=======================================================
//  Parameter/Wire/Reg coding
//=======================================================
parameter StartTime = 39999; 	// 时间到多少开始动画(VGA刚连上会有黑屏)，数值每10000是1秒
parameter ScrollTime = 59; 	// 多少时间向下移动1像素，数值每10000是1秒

reg  [9:0]	offsetY1;		// 控制从上到中
reg  [9:0]	offsetY2;		// 控制从中到下
wire [12:0]	real_v_addr = v_addr + offsetY1 - offsetY2;
wire [18:0] address = {h_addr[9:0], real_v_addr[8:0]};

wire [18:0] address = {h_addr[9:0], v_addr[8:0]};


wire [1:0]	colorMode;	// 值由下面的存储器给出
assign rgb_welcome = (
	(real_v_addr >= 480) ?	// 包含过大值和负值情况
	24'h0 :
	getColorByMode(colorMode)
);

// Timer
reg [19:0]	count;
reg [9:0]	count2;			// 滚屏需要
wire			welcomeclk;
reg [2:0]	state;
reg			KeyPressAccess;// Press any key to continue
reg			KeyPressed;

initial begin
	inWelcome = 1;
	// Initial
	offsetY1 = 480; 
	offsetY2 = 0;
	count = 0;
	count2 = 0;
	state = 0;
	KeyPressAccess = 0;
	KeyPressed = 0;
end

// 状态0：StartTime
// 状态1：从上面向中间滚动
// 状态2：在中间停留
// 状态3：从中间向下面移动
// 状态7：空状态

always @(posedge welcomeclk) begin
	if (state == 0) begin					// StartTime
		if (count < StartTime) begin
			count <= count + 1;
		end else begin
			count <= 0;
			state <= 1;
		end
	end else if (state == 1) begin		// 从上面向中间滚动
		if (count < ScrollTime) begin
			count <= count + 1;
		end else begin
			count <= 0;
			if (count2 < 480) begin
				count2 <= count2 + 1;
				offsetY1 <= offsetY1 - 1;
			end else begin
				count2 <= 0;
				state <= 2;
				KeyPressAccess <= 1;
			end
		end
	end else if (state == 2) begin		// 在中间停留
		if (KeyPressed)
			state <= 3;
	end else if (state == 3) begin		// 从中间向下面移动
		if (count < ScrollTime) begin
			count <= count + 1;
		end else begin
			count <= 0;
			if (count2 < 480) begin
				count2 <= count2 + 1;
				offsetY2 <= offsetY2 + 1;
			end else begin
				count2 <= 0;
				state <= 7;						// 空状态
			end
		end
	end else begin
		inWelcome <= 0;
	end
end

always @(posedge newKey) begin
	if (KeyPressAccess)
		KeyPressed <= 1;
end


//=======================================================
//  Module coding
//=======================================================
welcomeStorage WStorage(
	.address(address),
	.clock(clk),
	.q(colorMode)
);
clkgen #(10000) wCLK(
	.clkin(clk), 
	.rst(0), 
	.clken(1), 
	.clkout(welcomeclk)
);

//=======================================================
//  Color coding
//=======================================================
function [23:0] getColorByMode;
input [1:0] mode;
begin
	case (mode)
			0:	getColorByMode = 24'h000000;	// 黑色
			1:	getColorByMode = 24'hD2C4C1;	// 米色
			2:	getColorByMode = 24'hFFFFFF;	// 白色
	default:	getColorByMode = 24'h00C513;	// 绿色
	endcase
end
endfunction

endmodule
