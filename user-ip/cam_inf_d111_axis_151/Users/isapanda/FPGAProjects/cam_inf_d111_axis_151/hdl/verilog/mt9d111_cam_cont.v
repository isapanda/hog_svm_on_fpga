// MT9D111�J�����R���g���[��
// mt9d111_cam_cont.v
// 2012/12/26
//
// 2014/11/07 : fb_start_address ��ǉ��B���W�X�^�ɐݒ肳�ꂽ�l���X�^�[�g�A�h���X�Ƃ��ĎQ�ƁB
// 2014/11/08 : one_shot_state, one_shot_trigger �̓��̓|�[�g��ǉ�
// 2015/05/09 : UPSIDE_DOWN ���폜�Apifo_dout �� 64�r�b�g������ 32 �r�b�g���֕ύX�Apaddr ���폜
// 2015/05/11 : last_pixel_4_line ���o�͂��邽�߂ɁA�f�[�^��1�x�点�邱�ƂŁAline_valid �� falling edge �����o���Alast_pixel_4_line �Ƃ���Bfb_start_addres���폜

`default_nettype none

module mt9d111_cam_cont (
	input	wire	aclk,
	input	wire	areset,
	input	wire	pclk,
	input	wire	preset,
	input	wire	pclk_from_pll,
	output	wire	xclk,
	input	wire	line_valid,
	input	wire	frame_valid,
	input	wire	[7:0]	cam_data,
	output	wire	standby,
	input	wire	pfifo_rd_en,
	output	wire	[33:0]	pfifo_dout,
	output	wire	pfifo_empty,
	output	wire	pfifo_almost_empty,
	output	wire	[9:0]	pfifo_rd_data_count,
	output	wire	pfifo_overflow,
	output	wire	pfifo_underflow,
	input	wire	one_shot_state,		// 1�t���[������荞�񂾃J�����摜��ێ�����
	input	wire	one_shot_trigger	// 1�t���[�����̃J�����摜��荞�݂̃g���K�[�A1�N���b�N�p���X
);
	`include "./disp_timing_parameters.vh"

	// Frame Buffer End Address
	reg		line_valid_1d, line_valid_2d;
	reg		frame_valid_1d, frame_valid_2d;
	reg		[7:0]	cam_data_1d;
	reg		line_valid_1d_odd;
	reg		line_v_1d_odd_1d, line_v_1d_odd_2d;
	reg		[31:0]	rgb565, rgb565_1d;
	wire	pfifo_full, pfifo_almost_full;
	parameter	[1:0]	IDLE_ADDR_RST =	2'b00,
						ADDR_RST =		2'b01,
						ADDR_RST_HOLD =	2'b11;

	parameter	[2:0]	IDLE_OS =				3'b000,
						WAIT_FRAME_VALID_END =	3'b001,
						HOLD_PICTURE =			3'b011,
						WAIT_FRAME_VALID_LOW =	3'b010,
						WAIT_FRAME_VALID_HIGH =	3'b110;
	reg		[2:0]	one_shot_sm;
	reg    	frame_valid_1d_oh;
	reg		ost_1d, ost_2d, ost_3d, ost_4d;
	reg		one_shot_tig_pclk;
	reg		first_pixel;
	reg		last_pixel_4_line;
	reg		one_shot_state_1d, one_shot_state_2d;

	assign standby = 1'b0;

	// MT9D111 �ւ̃N���b�N���o�� (xclk)
	ODDR #(
		.DDR_CLK_EDGE("SAME_EDGE"), // "OPPOSITE_EDGE" or "SAME_EDGE"
		.INIT(1'b0), // Initial value of Q: 1'b0 or 1'b1
		.SRTYPE("SYNC") // Set/Reset type: "SYNC" or "ASYNC"
	) ODDR_inst (
		.Q(xclk), // 1-bit DDR output
		.C(pclk_from_pll), // 1-bit clock input
		.CE(1'b1), // 1-bit clock enable input
		.D1(1'b1), // 1-bit data input (positive edge)
		.D2(1'b0), // 1-bit data input (negative edge)
		.R(1'b0), // 1-bit reset
		.S(1'b0) // 1-bit set
	);

	// ���͐M������U���b�`����
	always @(posedge pclk) begin
		if (preset) begin
			line_valid_1d <=	1'b0;
			line_valid_2d <=	1'b0;
			frame_valid_1d <=	1'b0;
			frame_valid_2d <=	1'b0;
			cam_data_1d <=		8'd0;
		end else begin
			line_valid_1d <=	line_valid;
			line_valid_2d <= 	line_valid_1d;
			frame_valid_1d <=	frame_valid;
			frame_valid_2d <= 	frame_valid_1d;
			cam_data_1d <=		cam_data;
		end
	end

	// one_shot_state �� pclk �œ���������
	always @(posedge pclk) begin
		if (preset) begin
			one_shot_state_1d <= 1'b0;
			one_shot_state_2d <= 1'b0;
		end else begin
			one_shot_state_1d <= one_shot_state;
			one_shot_state_2d <= one_shot_state_1d;
		end
	end

	// one_shot_trigger�@��AXI�o�X��aclk�Ő�������Ă���̂ŁApclk�œ��삷��X�e�[�g�}�V���ł́A�{����one shot�ł͎��Ȃ�
	// ����āAone shot�ƌ����Ă�������x�̕���p�ӂ��Ă���Bpclk �̕���one shot pulse �����K�v������
	always @(posedge pclk) begin // one_shot_trigger ���@pclk �œ�����
		if (preset) begin
			ost_1d <= 1'b0;
			ost_2d <= 1'b0;
			ost_3d <= 1'b0;
			ost_4d <= 1'b0;
		end else begin
			ost_1d <= one_shot_trigger;
			ost_2d <= ost_1d;
			ost_3d <= ost_2d;
			ost_4d <= ost_3d;
		end
	end

	// pclk ���� one shot pulse �𐶐�
	always @(posedge pclk) begin
		if (preset) begin
			one_shot_tig_pclk <= 1'b0;
		end else if (ost_3d==1'b1 && ost_4d==1'b0) begin // rising edge
			one_shot_tig_pclk <= 1'b1;
		end else begin
			one_shot_tig_pclk <= 1'b0;
		end
	end
	
	// one shot state machine
	// frame_valid_1d_oh �𐶐�����
	always @(posedge pclk) begin
        if (preset) begin
            one_shot_sm <= IDLE_OS;
            frame_valid_1d_oh <= frame_valid_1d;
        end else begin
            case (one_shot_sm)
                IDLE_OS : begin
                    frame_valid_1d_oh <= frame_valid_1d;
                    if (one_shot_state_2d) begin
                        one_shot_sm <= WAIT_FRAME_VALID_END;
                    end
                end
                WAIT_FRAME_VALID_END : begin
                    frame_valid_1d_oh <= frame_valid_1d;
                    if (!frame_valid_1d) begin
                        one_shot_sm <= HOLD_PICTURE;
                    end
                end
                HOLD_PICTURE : begin
                    frame_valid_1d_oh <= 1'b0;
                    if (one_shot_tig_pclk) begin
                        one_shot_sm <= WAIT_FRAME_VALID_LOW;
                    end else if (~one_shot_state_2d & ~frame_valid_1d) begin
                        one_shot_sm <= IDLE_OS;
                    end
                end
                WAIT_FRAME_VALID_LOW : begin
                    frame_valid_1d_oh <= 1'b0;
                    if (!frame_valid_1d) begin
                        one_shot_sm <= WAIT_FRAME_VALID_HIGH;
                    end
                end
                WAIT_FRAME_VALID_HIGH : begin
                    frame_valid_1d_oh <= frame_valid_1d;
                    if (frame_valid_1d) begin
                        one_shot_sm <= WAIT_FRAME_VALID_END;
                    end
                end
            endcase
        end
    end

	// line_valid_1d ��������������J�E���g
	always @(posedge pclk) begin
		if (preset)
			line_valid_1d_odd <= 1'b0;
		else begin
			if (!frame_valid_1d_oh)
				line_valid_1d_odd <= 1'b0;
			else if (line_valid_1d)
				line_valid_1d_odd <= ~line_valid_1d_odd;
			else
				line_valid_1d_odd <= 1'b0;
		end
	end

	// rgb565�Ń��b�`���Ă���̂ŁAline_valid_1d_odd ��1�N���b�N�x������
	always @(posedge pclk) begin
		if (preset) begin
			line_v_1d_odd_1d <= 1'b0;
			line_v_1d_odd_2d <= 1'b0;
		end else begin
			line_v_1d_odd_1d <= line_valid_1d_odd;
			line_v_1d_odd_2d <= line_v_1d_odd_1d;
		end
	end

	// RGB565 �̃f�[�^��ۑ�����B����Ə㉺���]�ł̓o�C�g�z�񂪈قȂ�
	always @(posedge pclk) begin
		if (preset)
			rgb565 <= 32'd0;
		else begin
			case (line_valid_1d_odd)
				1'b0 : // 1�Ԗ�
					rgb565[31:13] <= {8'd0, cam_data_1d[7:3], 3'b000, cam_data_1d[2:0]};	// cam_data_1d = R7 R6 R5 R4 R3 G7 G6 G5
				1'b1 : // 2�Ԗ�
					rgb565[12:0] <= {cam_data_1d[7:5], 2'b00, cam_data_1d[4:0], 3'b000};	// cam_data_1d = G4 G3 G2 B7 B6 B5 B4 B3
			endcase
		end
	end

	// rgb565 �� 1 �N���b�N�x������
	always @(posedge pclk) begin
		if (preset) begin
			rgb565_1d <= 32'd0;
		end begin
			rgb565_1d <= rgb565;	
		end
	end

	// line_valid �� falling edge �̌��o
	always @(posedge pclk) begin
		if (preset) begin
			last_pixel_4_line <= 1'b0;
		end else if (line_valid_1d==1'b0 && line_valid_2d==1'b1) begin // line_valid_1d �� falling edge
			last_pixel_4_line <= 1'b1;
		end else if (line_v_1d_odd_2d) begin
			last_pixel_4_line <= 1'b0;
		end
	end

	// frame_valid �� 1 �ɂȂ��Ă��珉�߂Ẵs�N�Z��������
	always @(posedge pclk) begin
		if (preset) begin
			first_pixel <= 1'b0;
		end else if (frame_valid_1d==1'b1 && frame_valid_2d==1'b0) begin // frame_valid_1d rising edge
			first_pixel <= 1'b1;
		end else if (line_v_1d_odd_2d) begin // first pixel
			first_pixel <= 1'b0;
		end
	end

	// pixel FIFO ���C���X�^���X����
	pixel_fifo pfifo (
		.rst(areset), // input rst
		.wr_clk(pclk), // input wr_clk
		.rd_clk(aclk), // input rd_clk
		.din({last_pixel_4_line, first_pixel, rgb565_1d}), // input [33 : 0] din
		.wr_en(line_v_1d_odd_2d), // input wr_en
		.rd_en(pfifo_rd_en), // input rd_en
		.dout(pfifo_dout), // output [33 : 0] dout
		.full(pfifo_full), // output full
		.almost_full(pfifo_almost_full), // output almost_full
		.overflow(pfifo_overflow), // output overflow
		.empty(pfifo_empty), // output empty
		.almost_empty(pfifo_almost_empty), // output almost_empty
		.underflow(pfifo_underflow), // output underflow
		.rd_data_count(pfifo_rd_data_count) // output [9 : 0] rd_data_count
	);
endmodule

`default_nettype wire
