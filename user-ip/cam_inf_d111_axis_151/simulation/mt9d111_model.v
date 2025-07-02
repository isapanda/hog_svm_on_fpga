// mt9d111_model.v 
// mt9d111 の動作モデル
// RGB565 を出力

`default_nettype none
`timescale 1ns / 1ps

module mt9d111_model # (
	parameter	integer HORIZONTAL_PIXELS	= 800,
	parameter	integer	VERTICAL_LINES		= 600,
	parameter	integer	HBLANK_REG			= 174, 	// pixels
	parameter	integer	VBLANK_REG			= 16,	// rows
	parameter	integer	PCLK_DELAY			= 1
)(
	input	wire	xck,
	output	reg		pclk = 1'b1,
	output	reg		href = 1'b0,
	output	reg		vsync = 1'b1,
	output	reg		[7:0]	d = 8'd0,
	input	wire	scl,
	inout	wire	sda,
	input	wire	standby
);

	parameter	[2:0]	FRAME_START_BLANKING =	3'b000,
						ACTIVE_DATA_TIME =		3'b001,
						HORIZONTAL_BLANKING =	3'b011,
						FRAME_END_BLANKING =	3'b010,
						VERTICAL_BLANKING =		3'b110;
						
	reg		[2:0]	mt9d111_cs = VERTICAL_BLANKING;
	reg		[2:0]	fseb_count = 3'd5;
	reg		[15:0]	adt_count = (HORIZONTAL_PIXELS * 2) - 1;
	reg		[15:0]	hb_count = HBLANK_REG - 1;
	reg		[15:0]	fvt_count = VERTICAL_LINES - 1;
	reg		[31:0]	vb_count = VBLANK_REG * (HORIZONTAL_PIXELS + HBLANK_REG) - 1;
	reg		href_node = 1'b0;
	reg		vsync_node = 1'b0;
	reg		dout_is_even = 1'b0;

    // R, G, B 毎に違った生成多項式のM系列を用意した
	function [7:0] mseqf8_R (input [7:0] din);
        reg xor_result;
        begin
            xor_result = din[7] ^ din[3] ^ din[2] ^ din[1];
            mseqf8_R = {din[6:0], xor_result};
        end
    endfunction
    
    function [7:0] mseqf8_G (input [7:0] din);
        reg xor_result;
        begin
            xor_result = din[7] ^ din[4] ^ din[2] ^ din[0];
            mseqf8_G = {din[6:0], xor_result};
        end
    endfunction

    function [7:0] mseqf8_B (input [7:0] din);
        reg xor_result;
        begin
            xor_result = din[7] ^ din[5] ^ din[2] ^ din[1];
            mseqf8_B = {din[6:0], xor_result};
        end
    endfunction

	reg		[7:0]	mseq8r = 8'd1;
	reg		[7:0]	mseq8g = 8'd1;
	reg		[7:0]	mseq8b = 8'd1;
	
	// pclk の出力
	always @*
		pclk <= #PCLK_DELAY	xck;
		
	// MT9D111 のステート
	always @(posedge pclk) begin
		case (mt9d111_cs)
			FRAME_START_BLANKING : begin
				if (fseb_count==0) begin
					mt9d111_cs <= ACTIVE_DATA_TIME;
					href_node <= 1'b1;
				end
			end
			ACTIVE_DATA_TIME : begin
				if (adt_count==0) begin
					if (fvt_count==0)	// frame end
						mt9d111_cs <= FRAME_END_BLANKING;
					else
						mt9d111_cs <= HORIZONTAL_BLANKING;
					href_node <= 1'b0;
				end
			end
			HORIZONTAL_BLANKING : begin
				if (hb_count==0) begin
					mt9d111_cs <= ACTIVE_DATA_TIME;
					href_node <= 1'b1;
				end
			end
			FRAME_END_BLANKING : begin
				if (fseb_count==0) begin
					mt9d111_cs <= VERTICAL_BLANKING;
					vsync_node <= 1'b0;
				end
			end
			VERTICAL_BLANKING : begin
				if (vb_count==0) begin
					mt9d111_cs <= FRAME_START_BLANKING;
					vsync_node <= 1'b1;
				end
			end
		endcase
	end
				
	// vsync, href 出力、レーシングを防ぐためにpclk よりも出力を遅らせる
	always @* begin
		vsync <= #1	vsync_node;
		href <= #1	href_node;
	end
	
	// Frame Start/End Blanking Counter (6 pixel clocks)
	always @(posedge pclk) begin
		if (mt9d111_cs==FRAME_START_BLANKING || mt9d111_cs==FRAME_END_BLANKING) begin
			if (fseb_count > 0)
				fseb_count <= fseb_count - 3'd1;
		end else
			fseb_count <= 3'd5;
	end
	
	// Active Data Time Counter
	always @(posedge pclk) begin
		if (mt9d111_cs==ACTIVE_DATA_TIME) begin
			if (adt_count > 0)
				adt_count <= adt_count - 16'd1;
		end else
			adt_count <= (HORIZONTAL_PIXELS * 2) - 1;
	end
	
	// Horizontal Blanking Counter
	always @(posedge pclk) begin
		if (mt9d111_cs==HORIZONTAL_BLANKING) begin
			if (hb_count > 0)
				hb_count <= hb_count - 16'd1;
		end else
			hb_count <= HBLANK_REG - 1;
	end
	
	// Frame Valid Time Counter
	always @(posedge pclk) begin
		if (mt9d111_cs==ACTIVE_DATA_TIME && adt_count==0)
			fvt_count <= fvt_count - 16'd1;
		else if (mt9d111_cs==FRAME_END_BLANKING)
			fvt_count <= VERTICAL_LINES - 1;
	end
	
	// Vertical Blanking Counter
	always @(posedge pclk) begin
		if (mt9d111_cs==VERTICAL_BLANKING) begin
			if (vb_count > 0)
				vb_count <= vb_count - 32'd1;
		end else
			vb_count <= VBLANK_REG * (HORIZONTAL_PIXELS + HBLANK_REG) - 1;
	end
	
	// Red のM系列符号生成
	always @(posedge pclk) begin
		// if (mt9d111_cs==ACTIVE_DATA_TIME)
			mseq8r <= mseqf8_R(mseq8r);
	end
	
	// Green のM系列符号生成
	always @(posedge pclk) begin
		// if (mt9d111_cs==ACTIVE_DATA_TIME)
			mseq8g <= mseqf8_G(mseq8g);
	end
	
	// Blue のM系列符号生成
	always @(posedge pclk) begin
		// if (mt9d111_cs==ACTIVE_DATA_TIME)
			mseq8b <= mseqf8_B(mseq8b);
	end
	
	// d 出力のODD とEVEN を示す
	always @(posedge pclk) begin
		if (mt9d111_cs==ACTIVE_DATA_TIME)
			dout_is_even <= ~dout_is_even;
		else
			dout_is_even <= 1'b0;
	end
	
	// d 出力、レーシングを防ぐためにpclk よりも出力を遅らせる
	always @(posedge pclk) begin
		if (mt9d111_cs==ACTIVE_DATA_TIME) begin
			if (dout_is_even)
				d <= #1 {mseq8g[4:2], mseq8b[7:3]};
			else
				d <= #1 {mseq8r[7:3], mseq8g[7:5]};
		end
	end

endmodule

`default_nettype wire
