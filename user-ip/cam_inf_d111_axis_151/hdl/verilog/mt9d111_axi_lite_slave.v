// mt9d111_axi_lite_slave.v 
// mt9d111_inf_axi_master のAXI Lite Slave モジュール。Frame Buffer のスタートアドレス・レジスタを持つ。
//
// 2014/11/08 : one_shot_reg を実装。
// オフセット0番地：　フレーム・バッファの先頭アドレス(fb_start_address)
// オフセット4番地：　0 ビット目が 0 の時動画、0 ビット目に 1 の時に、ワンショットで取得した1フレームのカメラ画像を表示(one_shot_reg)
//　　　　　　　　　　　　1 ビット目に 1 を Write した時に、ワンショットで1フレームの画像をフレーム・バッファに保存
// 2014/11/11 : init_done を追加
//

`default_nettype none

module mt9d111_axi_lite_slave # (
	parameter integer C_S_AXI_LITE_ADDR_WIDTH = 9, // Address width of the AXI Lite Interface
	parameter integer C_S_AXI_LITE_DATA_WIDTH = 32, // Data width of the AXI Lite Interface
	
	parameter [31:0] C_DISPLAY_START_ADDRESS = 32'h1A00_0000,
	parameter integer ONE_SHOT_PULSE_LENGTH = 20   // 1ショットパルスの長さのAXI Lite Slave ACLKのクロック数をセット
)(
	input	wire									s_axi_lite_aclk,
	input	wire									axi_resetn,
	
	// AXI Lite Write Address Channel
	input	wire									s_axi_lite_awvalid,
	output	wire									s_axi_lite_awready,
	input	wire	[C_S_AXI_LITE_ADDR_WIDTH-1: 0]	s_axi_lite_awaddr,

	// AXI Lite Write Data Channel
	input	wire									s_axi_lite_wvalid,
	output	wire									s_axi_lite_wready,
	input	wire	[C_S_AXI_LITE_DATA_WIDTH-1: 0]	s_axi_lite_wdata,
	
	// AXI Lite Write Response Channel
	output	wire	[1:0]							s_axi_lite_bresp,
	output	wire									s_axi_lite_bvalid,
	input	wire									s_axi_lite_bready,

	// AXI Lite Read Address Channel
	input	wire									s_axi_lite_arvalid,
	output	wire									s_axi_lite_arready,
	input	wire	[C_S_AXI_LITE_ADDR_WIDTH-1: 0]	s_axi_lite_araddr,
	
	// AXI Lite Read Data Channel
	output	wire									s_axi_lite_rvalid,
	input	wire									s_axi_lite_rready,
	output	reg		[C_S_AXI_LITE_DATA_WIDTH-1: 0]	s_axi_lite_rdata,
	output	wire	[1:0]							s_axi_lite_rresp,
	
	output	wire	[31:0]							fb_start_address,	// Frame Buffer のスタートアドレス
	output	reg										init_done,			// fb_start_address に書き込まれた
	output	wire									one_shot_state,		// 1フレーム分取り込んだカメラ画像を保持する
	output	reg										one_shot_trigger	// 1フレーム分のカメラ画像取り込みのトリガー、1クロックパルス
);

	// RESP の値の定義
	parameter	RESP_OKAY =		2'b00;
	parameter	RESP_EXOKAY =	2'b01;
	parameter	RESP_SLVERR = 	2'b10;
	parameter	RESP_DECERR =	2'b11;
	
	parameter	[1:0]	IDLE_WR =			2'b00,	// for wrt_cs
						DATA_WRITE_HOLD =	2'b01,
						BREADY_ASSERT =		2'b11;
				
	parameter	IDLE_RD	=		1'b0,			//  for rdt_cs
				AR_DATA_WAIT =	1'b1;

	reg		[1:0]	wrt_cs = IDLE_WR;
	
	reg		[31:0]	fb_start_addr_reg = C_DISPLAY_START_ADDRESS;
	
	reg		rdt_cs = IDLE_RD;
	
	reg		reset_1d = 1'b0;
	reg		reset = 1'b0;
	reg		awready = 1'b1;
	reg		bvalid = 1'b0;
	reg		arready = 1'b1;
	reg		rvalid = 1'b0;
	wire		aclk;
	reg		[31:0]	one_shot_reg;

	parameter	[1:0]	IDLE_TSM =			2'b00,	// for one_shot_tsm
						WAIT_ONE_SHOT =		2'b01,
						ONE_SHOT_TRIG =		2'b11;
	reg		[1:0]	one_shot_tsm;
	integer	one_shot_counter;

	assign aclk = s_axi_lite_aclk;
	// Synchronization of axi_resetn
	always @(posedge aclk) begin
		reset_1d <= ~axi_resetn;
		reset <= reset_1d;
	end
	
	// AXI4 Lite Slave Write Transaction State Machine
	always @(posedge aclk) begin
		if (reset) begin
			wrt_cs <= IDLE_WR;
			awready <= 1'b1;
			bvalid <= 1'b0;
		end else begin
			case (wrt_cs)
				IDLE_WR :
					if (s_axi_lite_awvalid & ~s_axi_lite_wvalid) begin	// Write Transaction Start
						wrt_cs <= DATA_WRITE_HOLD;
						awready <= 1'b0;
					end else if (s_axi_lite_awvalid & s_axi_lite_wvalid) begin	// Write Transaction Start with data
						wrt_cs <= BREADY_ASSERT;
						awready <= 1'b0;
						bvalid <= 1'b1;
					end
				DATA_WRITE_HOLD :
					if (s_axi_lite_wvalid) begin	// Write data just valid
						wrt_cs <= BREADY_ASSERT;
						bvalid <= 1'b1;
					end
				BREADY_ASSERT :
					if (s_axi_lite_bready) begin	// The write transaction was terminated.
						wrt_cs <= IDLE_WR;
						bvalid <= 1'b0;
						awready <= 1'b1;
					end
			endcase
		end
	end
	assign s_axi_lite_awready = awready;
	assign s_axi_lite_bvalid = bvalid;
	assign s_axi_lite_wready = 1'b1;
	assign s_axi_lite_bresp = RESP_OKAY;
	
	// AXI4 Lite Slave Read Transaction State Machine
	always @(posedge aclk) begin
		if (reset) begin
			rdt_cs <= IDLE_RD;
			arready <= 1'b1;
			rvalid <= 1'b0;
		end else begin
			case (rdt_cs)
				IDLE_RD :
					if (s_axi_lite_arvalid) begin
						rdt_cs <= AR_DATA_WAIT;
						arready <= 1'b0;
						rvalid <= 1'b1;
					end
				AR_DATA_WAIT :
					if (s_axi_lite_rready) begin
						rdt_cs <= IDLE_RD;
						arready <= 1'b1;
						rvalid <= 1'b0;
					end
			endcase
		end
	end
	assign s_axi_lite_arready = arready;
	assign s_axi_lite_rvalid = rvalid;
	assign s_axi_lite_rresp = RESP_OKAY;
					
	// fb_start_addr_reg
	always @(posedge aclk) begin
		if (reset) begin
			init_done <= 1'b0;
			fb_start_addr_reg <= C_DISPLAY_START_ADDRESS;
		end else begin
			if (s_axi_lite_wvalid==1'b1 && s_axi_lite_awaddr[2]==1'b0) begin
				init_done <= 1'b1;
				fb_start_addr_reg <= s_axi_lite_wdata;
			end
		end
	end
	assign fb_start_address = fb_start_addr_reg;

	// one_shot_reg
	always @(posedge aclk) begin
		if (reset)
			one_shot_reg <= 32'd0;	// default is continuous display mode
		else
			if (s_axi_lite_wvalid==1'b1 && s_axi_lite_awaddr[2]==1'b1)
				one_shot_reg <= s_axi_lite_wdata;
	end
	assign one_shot_state = one_shot_reg[0];

	// one_shot_tsm(State Machine for one_shot_trgger)
	always @(posedge aclk) begin
		if (reset) begin
			one_shot_tsm <= IDLE_TSM;
			one_shot_trigger <= 1'b0;
		end else begin
			case (one_shot_tsm)
				IDLE_TSM :
					if (s_axi_lite_awvalid & awready & s_axi_lite_awaddr[2]) begin // one_shot_reg address
						if (s_axi_lite_wvalid) begin // s_axi_wready is always 1
							if (s_axi_lite_wdata[1]) begin // one_shot was triggered
								one_shot_tsm <= ONE_SHOT_TRIG;
								one_shot_trigger <= 1'b1;
							end else begin // is not trigger
								one_shot_tsm <= IDLE_TSM;
								one_shot_trigger <= 1'b0;
							end
						end else begin // s_axi_lite_wvalid is not asserted
							one_shot_tsm <= WAIT_ONE_SHOT;
							one_shot_trigger <= 1'b0;
						end
					end
				WAIT_ONE_SHOT :
					if (s_axi_lite_wvalid) begin // s_axi_wready is always 1
						if (s_axi_lite_wdata[1]) begin // one_shot was triggered
							one_shot_tsm <= ONE_SHOT_TRIG;
							one_shot_trigger <= 1'b1;
						end else begin // is not trigger
							one_shot_tsm <= IDLE_TSM;
							one_shot_trigger <= 1'b0;
						end
					end
				ONE_SHOT_TRIG : begin
					if (one_shot_counter == 0) begin
						one_shot_tsm <= IDLE_TSM;
						one_shot_trigger <= 1'b0;
					end
				end
			endcase
		end
	end

	// one shot pulse length counter
	always @(posedge aclk) begin
		if (reset) begin
			one_shot_counter <= ONE_SHOT_PULSE_LENGTH;
		end else if (one_shot_tsm == ONE_SHOT_TRIG) begin
			one_shot_counter <= one_shot_counter - 1;
		end else begin
			one_shot_counter <= ONE_SHOT_PULSE_LENGTH;
		end
	end
	// s_axi_lite_rdata
	always @(posedge aclk) begin
		if (reset) begin
			s_axi_lite_rdata <= 0;
		end else if (s_axi_lite_arvalid) begin
			case (s_axi_lite_araddr[2])
				1'b0 : 	s_axi_lite_rdata <= fb_start_addr_reg;
				1'b1 :	s_axi_lite_rdata <= one_shot_reg;
			endcase
		end
	end
endmodule
	
`default_nettype wire		
