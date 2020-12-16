module AudioHandler(
	input		clk,
	input		audio_ena,
	input		reset_n,
	//////////// AUDIO CONFIG //////////
	input 	AUD_ADCDAT,
	inout 	AUD_ADCLRCK,
	inout 	AUD_BCLK,
	output	AUD_DACDAT,
	inout 	AUD_DACLRCK,
	output	AUD_XCK,
	
	output	FPGA_I2C_SCLK,
	inout 	FPGA_I2C_SDAT,
	//////////// From Keyboard /////////////
	input	[15:0]	freq1,
	input	[15:0]	freq2,
	input	[8:0]		volume
);

//=======================================================
//  REG/WIRE declarations
//=======================================================

wire clk_i2c;
wire reset = !reset_n;
reg [15:0] audiodata;
(* ram_init_file = "init_files/sintable.mif" *) reg [15:0] sintable [1023:0]/*systhesis */;
reg [15:0] freq1_counter; //16bit counter
reg [15:0] freq2_counter; //16bit counter
wire [15:0] w1 = sintable[freq1_counter[15:6]];
wire [15:0] w2 = sintable[freq2_counter[15:6]];
wire [15:0] helper_w1 = {w1[15], w1[15:1]};
wire [15:0] helper_w2 = {w2[15], w2[15:1]};
reg config_reset_n;
reg refreshflag;
reg [8:0] last_volume;

initial begin
	freq1_counter = 0;
	freq2_counter = 0;
	config_reset_n = 1;
	refreshflag = 0;
	last_volume = 0;
end

//=======================================================
//  Structural coding
//=======================================================

//I2C part
audio_clk u1(clk, reset, AUD_XCK);
clkgen #(10000) my_i2c_clk(clk, reset, 1'b1, clk_i2c);  //10k I2C clock 
I2C_Audio_Config myconfig(clk_i2c, reset_n, FPGA_I2C_SCLK, FPGA_I2C_SDAT, , volume);
I2S_Audio myaudio(AUD_XCK, reset_n, AUD_BCLK, AUD_DACDAT, AUD_DACLRCK, audiodata);

//=======================================================
//  Logical coding
//=======================================================

always @(posedge clk) begin
	if (audio_ena) begin
		if (freq1 != 0 && freq2 != 0)
			audiodata <= helper_w1 + helper_w2;
		else if (freq1 != 0)
			audiodata <= w1;
		else if (freq2 != 0)
			audiodata <= w2;
	end else begin
		audiodata <= 0;
	end
	
	if (last_volume != volume) begin
		config_reset_n <= 0;
	end
	
	if (config_reset_n == 0)
		config_reset_n <= 1;
	
	last_volume <= volume;
end

always @(posedge AUD_DACLRCK or negedge reset_n) begin
	if (!reset_n) begin
	   freq1_counter <= 16'b0;
		freq2_counter <= 16'b0;
	end else begin
		freq1_counter <= freq1_counter + freq1;
		freq2_counter <= freq2_counter + freq2;
	end
end

endmodule
