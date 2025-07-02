// BitMap Display Controller
// bitmap_disp_engine.v
// AXI4バス用 by marsee
//
// 2014/07/26 : video_timing_param.vh を使用
// 2014/09/18 : フレームバッファのスタートアドレス入力を追加

`default_nettype none

// synthesis translate_off
// `include "std_ovl_defines.h"
// synthesis translate_on

module bitmap_disp_engine #(
		// video resolution : "VGA", "SVGA", "XGA", "SXGA", "HD"
        parameter [80*8:1] RESOLUTION                    ="SVGA"  // SVGA
) (
	input	wire	clk_disp,			// ディスプレイ表示用クロック
	input	wire	clk_axi,			// AXI4バスクロック
	input	wire	reset_disp,			// clk_disp 用リセット
	input	wire	reset_axi,			// clk_axi 用リセット
	output	reg		req,				// Read Address転送のrequest
	input	wire	ack,				// Read Address転送のacknowlege
	output	reg		[7:0]	ARLEN,		// Read Address転送のバースト長-1
	output	wire	[31:0]	address,	// AXI4 Busのアドレス
	input	wire	[63:0]	data_in,	// DDR2 SDRAMの画像データ(2つのRGB)
	input	wire	data_valid,
	output	reg		[7:0]	red_out,
	output	reg		[7:0]	green_out,
	output	reg  	[7:0]	blue_out,
	(*S="TRUE"*) output	reg 	hsyncx,
	(*S="TRUE"*) output	reg 	vsyncx,
	output	reg		display_enable,
	input	wire	ddr_cont_init_done,	// DDR2 SDRAMコントローラの初期化終了
	output	wire	afifo_overflow, // 非同期FIFO のオーバーフロー・エラー
	output	wire	afifo_underflow,	// 非同期FIFO のアンダーフロー・エラー
	output	reg		addr_is_zero,	// for test
	output	reg		h_v_is_zero,	// for test
	input	wire	[31:0]	fb_start_address	// フレームバッファのスタートアドレス
);
	`include "./video_timing_param.vh"

	parameter AFIFO_FULL_VAL = 9'b0_1000_0000; // Write側の値。Write側は32ビットなので、128でRead側は256となる
	parameter AFIFO_HALF_FULL_VAL = 9'b0_0100_0000; // Write側の値。Write側は32ビットなので、64でRead側は128となる

	parameter [5:0]	idle_rdg=			6'b000001,
					init_full_mode=		6'b000010,
					wait_half_full=		6'b000100,
					req_burst=			6'b001000,
					frame_wait_state=	6'b010000,
					frame_start_full=	6'b100000;
	reg	[5:0] cs_rdg;

	parameter [2:0]	IDLE_REQ =		3'b001,
					REQ_ASSERT =	3'b010,
					REQ_HOLD =		3'b100;
	reg [2:0]	cs_req;

	reg afifo_rd_en;
	wire [31:0] afifo_dout;
	wire afifo_full;
	wire afifo_empty;
	wire [8:0] wr_data_count;
	reg [31:0] addr_count;
	reg hv_count_enable;
	wire hv_count_ena_comb;
	reg [7:0] read_count;
	(* KEEP="TURE" *) reg hv_cnt_ena_d1;
	(* KEEP="TURE" *) reg hv_cnt_ena_d2;
	reg [15:0] h_count;
	reg [15:0] v_count;
	reg [7:0] red_node, green_node, blue_node;
	reg hsyncx_node, vsyncx_node;
	reg addr_is_zero_node, h_v_is_zero_node;
	reg vsync_axi, vsync_axi_b1;
	reg vsync_axi_1d;
	reg vsyncx_rise_pulse;

	// synthesis translate_off
	// wire [`OVL_FIRE_WIDTH-1:0] fire_overflow, fire_underflow;
	// synthesis translate_on

	// RGB保存用非同期FIFO, FWFT Wirte側64ビット幅128深度、Read側32ビット256深度とする
	bitmap_afifo bitmap_afifo_inst (
		.wr_rst(reset_axi | vsync_axi),
		.wr_clk(clk_axi),
		.rd_clk(clk_disp),
		.rd_rst(reset_disp | ~vsyncx_node),
		//.din(data_in), // Bus [63 : 0]
		.din({data_in[31:0], data_in[63:32]}), // Bus [63 : 0]
		.wr_en(data_valid),
		.rd_en(afifo_rd_en),
		.dout(afifo_dout), // Bus [31 : 0]
		.full(afifo_full),
		.overflow(afifo_overflow),
		.empty(afifo_empty),
		.underflow(afifo_underflow),
		.wr_data_count(wr_data_count) // output wire [8 : 0] wr_data_count
	);

	// AXI4 Busのアドレスカウンタ（AXI4クロックドメイン）カウンタの単位は1バイト
	always @(posedge clk_axi) begin
		if (reset_axi)
			addr_count <= fb_start_address;
		else begin
			// if (addr_count>=(fb_start_address + (H_ACTIVE_VIDEO * V_ACTIVE_VIDEO *4))) // 1フレーム分描画終了したのでクリアする（1ピクセルに3バイト使用する。つまり32ビット(4bytes)使用するので*4する)
			if (vsync_axi)
				addr_count <= fb_start_address;
			else if (data_valid) // データが来たらカウントアップ
				addr_count <= addr_count + 32'd8; // 1回のデータは64ビット長（8バイト）
		end
	end
	assign address = addr_count;

	// Readデータ処理モジュール用ステートマシン
	always @(posedge clk_axi) begin
		if (reset_axi)
			cs_rdg <= idle_rdg;
		else begin
			case (cs_rdg)
				idle_rdg :
					if (ddr_cont_init_done)
						cs_rdg <= init_full_mode;
				init_full_mode : // 最初にcam_data_afifo をFULLにするステート、このステートではVGA信号は出力しないで、ひたすらcam_data_afifo がFULLになるのを待つ。
					if (read_count==0)
						cs_rdg <= wait_half_full;
				wait_half_full : // cam_data_afifo がHALF_FULLになるまでこのステートで待機
					if (vsync_axi)
						cs_rdg <= frame_wait_state;
					else if (wr_data_count<=AFIFO_HALF_FULL_VAL)
						cs_rdg <= req_burst;
				req_burst :
					if (vsync_axi)
						cs_rdg <= frame_wait_state;
					else if (read_count==0) // データが全部来たら
						cs_rdg <= wait_half_full;
				frame_wait_state : // 1フレーム終了後vsync の時にWaitする
					if (vsyncx_rise_pulse) // vsyncx の立ち上がり
						cs_rdg <= frame_start_full;
				frame_start_full : // 1フレームのスタートの時にFIFOをフルにする
					if (read_count==0)
						cs_rdg <= wait_half_full;
			endcase
		end
	end
    assign hv_count_ena_comb = (cs_rdg==wait_half_full || cs_rdg==req_burst || cs_rdg==frame_wait_state || cs_rdg==frame_start_full) ? 1'b1 : 1'b0;
    always @(posedge clk_axi) begin
        if (reset_axi) begin
            hv_count_enable <= 1'b0;
        end else begin
            hv_count_enable <= hv_count_ena_comb;
        end
    end
    
	// req の実装。VRAMのデータをReadしたいときにアクティベート。ackが帰ってきたら落とす
	always @(posedge clk_axi) begin
		if (reset_axi) begin
			cs_req <= IDLE_REQ;
			req <= 1'b0;
		end else begin
			case (cs_req)
				IDLE_REQ :
					if (cs_rdg==req_burst || cs_rdg==init_full_mode || cs_rdg==frame_start_full) begin
						cs_req <= REQ_ASSERT;
						req <= 1'b1;
					end
				REQ_ASSERT :
					if (ack) begin
						cs_req <= REQ_HOLD;
						req <= 1'b0;
					end
				REQ_HOLD :
					if (~(cs_rdg==req_burst || cs_rdg==init_full_mode || cs_rdg==frame_start_full))
						cs_req <= IDLE_REQ;
			endcase
		end
	end

	// ARLEN, read_count の決定。 init_full_mode,frame_start_full  の時はAFIFO_FULL_VAL-1、それ以外はAFIFO_HALF_FULL_VAL-1
	always @(posedge clk_axi) begin
		if (reset_axi) begin
			ARLEN <= AFIFO_FULL_VAL-1;
			read_count <= AFIFO_FULL_VAL;
		end else begin
			if (cs_rdg==idle_rdg || cs_rdg==frame_wait_state) begin
				ARLEN <= AFIFO_FULL_VAL-1;
				read_count <= AFIFO_FULL_VAL;
			end else if (cs_rdg==wait_half_full) begin
				ARLEN <= AFIFO_HALF_FULL_VAL-1;
				read_count <= AFIFO_HALF_FULL_VAL;
			end else if (cs_rdg==req_burst || cs_rdg==init_full_mode || cs_rdg==frame_start_full) begin
				if (read_count!=0 && data_valid) // 0になるまで、データが来たらデクリメント
					read_count <= read_count - 1;
			end
		end
	end

	// read_count の実装、AXI4 Bus Interface へのRead要求のカウントをする。
	// always @(posedge clk_axi) begin
		// if (reset_axi)
			// read_count <= ARLEN+1;
		// else begin
			// if (cs_rdg==wait_half_full || cs_rdg==idle_rdg)
				// read_count <= ARLEN+1;
			// else if (cs_rdg==req_burst || cs_rdg==init_full_mode) begin
				// if (read_count!=0 && data_valid) // 0になるまで、データが来たらデクリメント
					// read_count <= read_count - 1;
			// end
		// end
	// end

	// ビットマップVGAコントローラのclk_disp 動作部

	// h_count、v_count用にclk_axi 動作のcs_rdg の値を使用するので2回clk_disp 動作のFFでラッチする
	always @(posedge clk_disp) begin
		if (reset_disp) begin
			hv_cnt_ena_d1 <= 1'b0;
			hv_cnt_ena_d2 <= 1'b0;
		end else begin
			hv_cnt_ena_d1 <= hv_count_enable;
			hv_cnt_ena_d2 <= hv_cnt_ena_d1;
		end
	end

	// h_countの実装（水平カウンタ）
	always @(posedge clk_disp) begin
		if (reset_disp)
			h_count <= 0;
		else if (h_count>=(H_SUM-1)) // h_count がH_SUM-1よりも大きければ0に戻す(mod H_SUM)
			h_count <= 0;
		else if (hv_cnt_ena_d2) // 最初に非同期FIFOをフルにするまではカウントしない
			h_count <= h_count + 1;
	end

	// v_countの実装（垂直カウンタ）
	always @(posedge clk_disp) begin
		if (reset_disp)
			v_count <= 0;
		else if (h_count>=(H_SUM-1)) begin // 水平カウンタがクリアされるとき
			if (v_count>=(V_SUM-1)) // v_count がV_SUM-1よりも大きければ0に戻す(mode V_SUM)
				v_count <= 0;
			else if (hv_cnt_ena_d2) // 最初に非同期FIFOをフルにするまではカウントしない
				v_count <= v_count + 1;
		end
	end

	// Red, Green, Blue出力
	always @(posedge clk_disp) begin
		if (reset_disp) begin
			red_node <= 0;
			green_node <= 0;
			blue_node <= 0;
		end else begin
			if (~hv_cnt_ena_d2) begin // 最初にpixel_async_fifo がフルになるまで画像データを出力しない。
				red_node <= 0;
				green_node <= 0;
				blue_node <= 0;
			end else if (h_count<H_ACTIVE_VIDEO && v_count<V_ACTIVE_VIDEO) begin
				red_node <= afifo_dout[23:16];
				green_node <= afifo_dout[15:8];
				blue_node <= afifo_dout[7:0];
			end else begin
				red_node <= 0;
				green_node <= 0;
				blue_node <= 0;
			end

		end
	end
	always @(posedge clk_disp) begin
		if (reset_disp) begin
			red_out <= 0;
			green_out <= 0;
			blue_out <= 0;
		end else begin
			red_out <= red_node;
			green_out <= green_node;
			blue_out <= blue_node;
		end
	end

	// hsyncx 出力（水平同期信号）
	always @(posedge clk_disp) begin
		if (reset_disp)
			hsyncx_node <= 1'b1;
		else
			if (h_count>(H_ACTIVE_VIDEO + H_FRONT_PORCH-1) && h_count<=(H_ACTIVE_VIDEO + H_FRONT_PORCH + H_SYNC_PULSE-1)) // 水平同期期間
				hsyncx_node <= 1'b0;
			else
				hsyncx_node <= 1'b1;
	end
	always @(posedge clk_disp) begin
		if (reset_disp)
			hsyncx <= 1'b1;
		else
			hsyncx <= hsyncx_node;
	end

	// vsyncx 出力（水平同期信号）
	always @(posedge clk_disp) begin
		if (reset_disp)
			vsyncx_node <= 1'b1;
		else
			if (v_count>(V_ACTIVE_VIDEO + V_FRONT_PORCH-1) && v_count<=(V_ACTIVE_VIDEO + V_FRONT_PORCH + V_SYNC_PULSE-1)) // 垂直同期期間
				vsyncx_node <= 1'b0;
			else
				vsyncx_node <= 1'b1;
	end
	always @(posedge clk_disp) begin
		if (reset_disp)
			vsyncx <= 1'b1;
		else
			vsyncx <= vsyncx_node;
	end

	// vsync をclk_axi で同期化
	always @(posedge clk_axi) begin
		if (reset_axi) begin
			vsync_axi		<= 1'b0;
			vsync_axi_b1	<= 1'b0;
			vsync_axi_1d	<= 1'b0;
		end else begin
			vsync_axi_b1 	<= ~vsyncx_node;
			vsync_axi 		<= vsync_axi_b1;
			vsync_axi_1d	<= vsync_axi;
		end
	end

	// vsyncx_rise_pulse の処理。vsyncx の立ち上がり時に1パルス出力する
	always @(posedge clk_axi) begin
		if (reset_axi)
			vsyncx_rise_pulse <= 1'b0;
		else begin
			if (vsync_axi==1'b0 && vsync_axi_1d==1'b1)
				vsyncx_rise_pulse <= 1'b1;
			else
				vsyncx_rise_pulse <= 1'b0;
		end
	end

	// display_enable 出力
	always @(posedge clk_disp) begin
		if (reset_disp)
			display_enable <= 1'b1;
		else begin
			if (h_count<H_ACTIVE_VIDEO && v_count<V_ACTIVE_VIDEO)
				display_enable <= 1'b1;
			else
				display_enable <= 1'b0;
		end
	end

	// afifo_rd_en の処理
	always @(posedge clk_disp) begin
		if (reset_disp)
			afifo_rd_en <= 1'b0;
		else begin
			if (~hv_cnt_ena_d2) // 初期化中
				afifo_rd_en <= 1'b0;
			else if (h_count<H_ACTIVE_VIDEO && v_count<V_ACTIVE_VIDEO) // 表示期間
				afifo_rd_en <= 1'b1;
			else
				afifo_rd_en <= 1'b0;
		end
	end


	// アサーション
	// synthesis translate_off
	always @ (posedge clk_axi) begin
		if (reset_axi)
			;
		else begin
			if (afifo_overflow) begin
				$display("%m: at time %t ERROR : FIFOがフルなのにライトした",$time);
				$stop;
			end
		end
	end
	always @(posedge clk_disp) begin
		if (reset_disp)
			;
		else begin
			if (afifo_underflow) begin
				$display("%m: at time %t ERROR : FIFOが空なのにリードした",$time);
				// $stop;
			end
		end
	end

	// ovl_never #(
		// `OVL_ERROR,			// severity_level
		// `OVL_ASSERT,		// property_type
		// "ERROR : FIFOがフルなのにライトした", // msg
		// `OVL_COVER_DEFAULT,	// coverage_level
		// `OVL_POSEDGE,		// clock_edge
		// `OVL_ACTIVE_HIGH,	// reset_polarity
		// `OVL_GATE_CLOCK	// gating_type
	// ) afifo_overflow_assertion (
		// clk_axi,
		// reset_axi,
		// 1'b1,
		// afifo_overflow,
		// fire_overflow
	// );

	// ovl_never #(
		// `OVL_ERROR,			// severity_level
		// `OVL_ASSERT,		// property_type
		// "ERROR : FIFOが空なのにリードした", // msg
		// `OVL_COVER_DEFAULT,	// coverage_level
		// `OVL_POSEDGE,		// clock_edge
		// `OVL_ACTIVE_HIGH,	// reset_polarity
		// `OVL_GATE_CLOCK	// gating_type
	// ) afifo_underflow_assertion (
		// clk_disp,
		// reset_disp,
		// 1'b1,
		// afifo_underflow,
		// fire_underflow
	// );
	// synthesis translate_on

	//  for test
	always @(posedge clk_axi) begin
		if (reset_axi) begin
			addr_is_zero_node <= 1'b0;
			addr_is_zero <= 1'b0;
		end else begin
			if (addr_count == 0)
				addr_is_zero_node <= 1'b1;
			else
				addr_is_zero_node <= 1'b0;
			addr_is_zero <= addr_is_zero_node;
		end
	end
	always @(posedge clk_disp) begin
		if (reset_disp) begin
			h_v_is_zero_node <= 1'b0;
			h_v_is_zero <= 1'b0;
		end else begin
			if (h_count==0 && v_count==0)
				h_v_is_zero_node <= 1'b1;
			else
				h_v_is_zero_node <= 1'b0;
			h_v_is_zero <= h_v_is_zero_node;
		end
	end

endmodule

`default_nettype wire
