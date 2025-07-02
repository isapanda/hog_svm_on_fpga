// bmd_controller_axim.v
//
// by marsee
//
// Read Only IP, 64 bit bus
//
// 2012/06/28
// 2012/11/22 : HDMI出力を追加
// 2014/07/23 : ZYBO 用に変更
// 2014/09/18 : Frame Buffer のスタートアドレスを設定するためにAXI4 Lite Slave インターフェースを追加
// 2018/07/20 : bmd_controller_aximにファイル名とモジュール名を変更
//

`default_nettype none

module bmd_controller_axim #
  (
		// AXI4 Lite Slave Interface
		parameter integer C_S_AXI_LITE_ADDR_WIDTH		= 9,
		parameter integer C_S_AXI_LITE_DATA_WIDTH		= 32,

		// AXI Master Interface
		parameter integer C_INTERCONNECT_M_AXI_WRITE_ISSUING = 8,
		parameter integer C_M_AXI_THREAD_ID_WIDTH       = 1,
		parameter integer C_M_AXI_ADDR_WIDTH            = 32,
		parameter integer C_M_AXI_DATA_WIDTH            = 64,
		parameter integer C_M_AXI_AWUSER_WIDTH          = 1,
		parameter integer C_M_AXI_ARUSER_WIDTH          = 1,
		parameter integer C_M_AXI_WUSER_WIDTH           = 1,
		parameter integer C_M_AXI_RUSER_WIDTH           = 1,
		parameter integer C_M_AXI_BUSER_WIDTH           = 1,
		parameter [31:0]  C_M_AXI_TARGET 				= 32'h00000000,
		parameter integer C_M_AXI_BURST_LEN				= 256,
		parameter integer C_OFFSET_WIDTH				= 32,

		/* Disabling these parameters will remove any throttling.
		The resulting ERROR flag will not be useful */
		parameter integer C_M_AXI_SUPPORTS_WRITE         = 0,
		parameter integer C_M_AXI_SUPPORTS_READ         = 1,

		parameter [31:0]	C_DISPLAY_START_ADDRESS		= 32'h17800000,	// フレームバッファのスタートアドレス

        // video resolution : "VGA", "SVGA", "XGA", "SXGA", "HD"
        parameter [80*8:1] RESOLUTION                    ="SVGA"  // SVGA
	)
	(
		// Clocks and Reset
		input wire		  s_axi_lite_aclk,
		input wire 	      M_AXI_ACLK,
		input wire 	      ARESETN,

		///////////////////////////////
		// AXI4 Lite Slave Interface //
		///////////////////////////////
		// AXI Lite Write Address Channel
		input	wire	s_axi_lite_awvalid,
		output	wire	s_axi_lite_awready,
		input	wire	[C_S_AXI_LITE_ADDR_WIDTH-1:0]	s_axi_lite_awaddr,

		// AXI Lite Write Data Channel
		input	wire	s_axi_lite_wvalid,
		output	wire	s_axi_lite_wready,
		input	wire	[C_S_AXI_LITE_DATA_WIDTH-1:0] s_axi_lite_wdata,

		// AXI Lite Write Response Channel
		output	wire	[1:0]	s_axi_lite_bresp,
		output	wire	s_axi_lite_bvalid,
		input	wire	s_axi_lite_bready,

		// AXI Lite Read Address Channel
		input	wire	s_axi_lite_arvalid,
		output	wire	s_axi_lite_arready,
		input	wire	[C_S_AXI_LITE_ADDR_WIDTH-1:0]	s_axi_lite_araddr,

		// AXI Lite Read Data Channel
		output	wire	s_axi_lite_rvalid,
		input	wire	s_axi_lite_rready,
		output	wire	[C_S_AXI_LITE_DATA_WIDTH-1:0] s_axi_lite_rdata,
		output	wire	[1:0]	s_axi_lite_rresp,

		///////////////////////////////
		// AXI4 Master Interface //
		///////////////////////////////
		// Master Interface Write Address
		output wire [C_M_AXI_THREAD_ID_WIDTH-1:0] M_AXI_AWID,
		output wire [C_M_AXI_ADDR_WIDTH-1:0]      M_AXI_AWADDR,
		output wire [8-1:0]                       M_AXI_AWLEN,
		output wire [3-1:0]                       M_AXI_AWSIZE,
		output wire [2-1:0]                       M_AXI_AWBURST,
		output wire                               M_AXI_AWLOCK,
		output wire [4-1:0]                       M_AXI_AWCACHE,
		output wire [3-1:0]                       M_AXI_AWPROT,
		// AXI3 output wire [4-1:0]                  M_AXI_AWREGION,
		output wire [4-1:0]                       M_AXI_AWQOS,
		output wire [C_M_AXI_AWUSER_WIDTH-1:0]    M_AXI_AWUSER,
		output wire                               M_AXI_AWVALID,
		input  wire                               M_AXI_AWREADY,

		// Master Interface Write Data
		// AXI3 output wire [C_M_AXI_THREAD_ID_WIDTH-1:0]     M_AXI_WID,
		output wire [C_M_AXI_DATA_WIDTH-1:0]      M_AXI_WDATA,
		output wire [C_M_AXI_DATA_WIDTH/8-1:0]    M_AXI_WSTRB,
		output wire                               M_AXI_WLAST,
		output wire [C_M_AXI_WUSER_WIDTH-1:0]     M_AXI_WUSER,
		output wire                               M_AXI_WVALID,
		input  wire                               M_AXI_WREADY,

		// Master Interface Write Response
		input  wire [C_M_AXI_THREAD_ID_WIDTH-1:0] M_AXI_BID,
		input  wire [2-1:0]                       M_AXI_BRESP,
		input  wire [C_M_AXI_BUSER_WIDTH-1:0]     M_AXI_BUSER,
		input  wire                               M_AXI_BVALID,
		output wire                               M_AXI_BREADY,

		// Master Interface Read Address
		output wire [C_M_AXI_THREAD_ID_WIDTH-1:0] M_AXI_ARID,
		output wire [C_M_AXI_ADDR_WIDTH-1:0]      M_AXI_ARADDR,
		output wire [8-1:0]                       M_AXI_ARLEN,
		output wire [3-1:0]                       M_AXI_ARSIZE,
		output wire [2-1:0]                       M_AXI_ARBURST,
		output wire [2-1:0]                       M_AXI_ARLOCK,
		output wire [4-1:0]                       M_AXI_ARCACHE,
		output wire [3-1:0]                       M_AXI_ARPROT,
		// AXI3 output wire [4-1:0] 		 M_AXI_ARREGION,
		output wire [4-1:0]                        M_AXI_ARQOS,
		output wire [C_M_AXI_ARUSER_WIDTH-1:0]     M_AXI_ARUSER,
		output wire                                M_AXI_ARVALID,
		input  wire                                M_AXI_ARREADY,

		// Master Interface Read Data
		input  wire [C_M_AXI_THREAD_ID_WIDTH-1:0]  M_AXI_RID,
		input  wire [C_M_AXI_DATA_WIDTH-1:0] 	   M_AXI_RDATA,
		input  wire [2-1:0] 			           M_AXI_RRESP,
		input  wire 				               M_AXI_RLAST,
		input  wire [C_M_AXI_RUSER_WIDTH-1:0] 	   M_AXI_RUSER,
		input  wire 				               M_AXI_RVALID,
		output wire 				               M_AXI_RREADY,

		// User Ports
		input	wire	clk25,

		(* IOB = "FORCE" *) output	reg	 [4:0]	vga_red,
		(* IOB = "FORCE" *) output	reg	 [5:0]	vga_green,
		(* IOB = "FORCE" *) output	reg	 [4:0]	vga_blue,
		(* IOB = "FORCE" *) output	reg		vga_hsync,
		(* IOB = "FORCE" *) output	reg		vga_vsync,

        output  wire    TMDS_tx_clk_p,
        output  wire    TMDS_tx_clk_n,
        output  wire    TMDS_tx_2_G_p,
        output  wire    TMDS_tx_2_G_n,
        output  wire    TMDS_tx_1_R_p,
        output  wire    TMDS_tx_1_R_n,
        output  wire    TMDS_tx_0_B_p,
        output  wire    TMDS_tx_0_B_n
	);

    `include "mmcm_parameters.vh"

	wire	[7:0]	red, green, blue;
	wire	hsyncx, vsyncx;
	wire	display_enable;
	wire	bde_req, bde_ack;
	wire	[7:0]	bde_arlen;
	wire	[31:0]	bde_address;
	wire	[63:0]	bde_data;
	wire	bde_data_valid;
	reg		reset_disp_2b = 1'b1, reset_disp_1b = 1'b1;
	wire	reset_disp;
	wire	afifo_overflow, afifo_underflow;
	wire	addr_is_zero, h_v_is_zero;
    wire    pixclk;
    wire    reset_out;
    wire     [31:0]  fb_start_address;
    wire	pixclk_locked, pixclk_locked_n;
    wire	init_done;

	bm_disp_cntrler_axi_lite_slave #(
		.C_S_AXI_LITE_ADDR_WIDTH(C_S_AXI_LITE_ADDR_WIDTH),
		.C_S_AXI_LITE_DATA_WIDTH(C_S_AXI_LITE_DATA_WIDTH),
		.C_DISPLAY_START_ADDRESS(C_DISPLAY_START_ADDRESS)
	) bm_disp_cntrler_axi_lite_slave_i
	(
		.s_axi_lite_aclk(s_axi_lite_aclk),
		.axi_resetn(ARESETN),
		.s_axi_lite_awvalid(s_axi_lite_awvalid),
		.s_axi_lite_awready(s_axi_lite_awready),
		.s_axi_lite_awaddr(s_axi_lite_awaddr),
		.s_axi_lite_wvalid(s_axi_lite_wvalid),
		.s_axi_lite_wready(s_axi_lite_wready),
		.s_axi_lite_wdata(s_axi_lite_wdata),
		.s_axi_lite_bresp(s_axi_lite_bresp),
		.s_axi_lite_bvalid(s_axi_lite_bvalid),
		.s_axi_lite_bready(s_axi_lite_bready),
		.s_axi_lite_arvalid(s_axi_lite_arvalid),
		.s_axi_lite_arready(s_axi_lite_arready),
		.s_axi_lite_araddr(s_axi_lite_araddr),
		.s_axi_lite_rvalid(s_axi_lite_rvalid),
		.s_axi_lite_rready(s_axi_lite_rready),
		.s_axi_lite_rdata(s_axi_lite_rdata),
		.s_axi_lite_rresp(s_axi_lite_rresp),
		.fb_start_address(fb_start_address),
		.init_done(init_done)
	);

	axi_master_interface #(
		.C_M_AXI_THREAD_ID_WIDTH(C_M_AXI_THREAD_ID_WIDTH),
		.C_M_AXI_ADDR_WIDTH(C_M_AXI_ADDR_WIDTH),
		.C_M_AXI_DATA_WIDTH(C_M_AXI_DATA_WIDTH),
		.C_M_AXI_AWUSER_WIDTH(C_M_AXI_AWUSER_WIDTH),
		.C_M_AXI_ARUSER_WIDTH(C_M_AXI_ARUSER_WIDTH),
		.C_M_AXI_WUSER_WIDTH(C_M_AXI_WUSER_WIDTH),
		.C_M_AXI_RUSER_WIDTH(C_M_AXI_RUSER_WIDTH),
		.C_M_AXI_BUSER_WIDTH(C_M_AXI_BUSER_WIDTH),
		.C_M_AXI_SUPPORTS_WRITE(C_M_AXI_SUPPORTS_WRITE),
		.C_M_AXI_SUPPORTS_READ(C_M_AXI_SUPPORTS_READ)
	) axi_master_inf_inst
	(
		.ACLK(M_AXI_ACLK),
		.ARESETN(ARESETN),
		.M_AXI_AWID(M_AXI_AWID),
		.M_AXI_AWADDR(M_AXI_AWADDR),
		.M_AXI_AWLEN(M_AXI_AWLEN),
		.M_AXI_AWSIZE(M_AXI_AWSIZE),
		.M_AXI_AWBURST(M_AXI_AWBURST),
		.M_AXI_AWLOCK(M_AXI_AWLOCK),
		.M_AXI_AWCACHE(M_AXI_AWCACHE),
		.M_AXI_AWPROT(M_AXI_AWPROT),
		.M_AXI_AWQOS(M_AXI_AWQOS),
		.M_AXI_AWUSER(M_AXI_AWUSER),
		.M_AXI_AWVALID(M_AXI_AWVALID),
		.M_AXI_AWREADY(M_AXI_AWREADY),
		.M_AXI_WDATA(M_AXI_WDATA),
		.M_AXI_WSTRB(M_AXI_WSTRB),
		.M_AXI_WLAST(M_AXI_WLAST),
		.M_AXI_WUSER(M_AXI_WUSER),
		.M_AXI_WVALID(M_AXI_WVALID),
		.M_AXI_WREADY(M_AXI_WREADY),
		.M_AXI_BID(M_AXI_BID),
		.M_AXI_BRESP(M_AXI_BRESP),
		.M_AXI_BUSER(M_AXI_BUSER),
		.M_AXI_BVALID(M_AXI_BVALID),
		.M_AXI_BREADY(M_AXI_BREADY),
		.M_AXI_ARID(M_AXI_ARID),
		.M_AXI_ARADDR(M_AXI_ARADDR),
		.M_AXI_ARLEN(M_AXI_ARLEN),
		.M_AXI_ARSIZE(M_AXI_ARSIZE),
		.M_AXI_ARBURST(M_AXI_ARBURST),
		.M_AXI_ARLOCK(M_AXI_ARLOCK),
		.M_AXI_ARCACHE(M_AXI_ARCACHE),
		.M_AXI_ARPROT(M_AXI_ARPROT),
		.M_AXI_ARQOS(M_AXI_ARQOS),
		.M_AXI_ARUSER(M_AXI_ARUSER),
		.M_AXI_ARVALID(M_AXI_ARVALID),
		.M_AXI_ARREADY(M_AXI_ARREADY),
		.M_AXI_RID(M_AXI_RID),
		.M_AXI_RDATA(M_AXI_RDATA),
		.M_AXI_RRESP(M_AXI_RRESP),
		.M_AXI_RLAST(M_AXI_RLAST),
		.M_AXI_RUSER(M_AXI_RUSER),
		.M_AXI_RVALID(M_AXI_RVALID),
		.M_AXI_RREADY(M_AXI_RREADY),

		.bde_req(bde_req),
		.bde_ack(bde_ack),
		.bde_arlen(bde_arlen),
		.bde_address(bde_address),
		.bde_data_out(bde_data),
		.bde_data_valid(bde_data_valid)
	);

	bitmap_disp_engine #(
        .RESOLUTION(RESOLUTION)
    ) bitmap_disp_eng_inst (
		.clk_disp(pixclk),
		.clk_axi(M_AXI_ACLK),
		.reset_disp(reset_disp),
		.reset_axi(~ARESETN),
		.req(bde_req),
		.ack(bde_ack),
		.ARLEN(bde_arlen),
		.address(bde_address),
		.data_in(bde_data),
		.data_valid(bde_data_valid),
		.red_out(red),
		.green_out(green),
		.blue_out(blue),
		.hsyncx(hsyncx),
		.vsyncx(vsyncx),
		.display_enable(display_enable),
		.ddr_cont_init_done(init_done),
		.afifo_overflow(afifo_overflow),
		.afifo_underflow(afifo_underflow),
		.addr_is_zero(addr_is_zero),
		.h_v_is_zero(h_v_is_zero),
		.fb_start_address(fb_start_address)
	);

	always @(posedge pixclk) begin
		if (reset_disp) begin
			vga_red <= 5'd0;
			vga_green <= 6'd0;
			vga_blue <= 5'd0;
			vga_hsync <= 1'b1;
			vga_vsync <= 1'b1;
		end else begin
			vga_red <= red[7:3];
			vga_green <= green[7:2];
			vga_blue <= blue[7:3];
			vga_hsync <= hsyncx;
			vga_vsync <= vsyncx;
		end
	end

	always @(posedge pixclk) begin
		reset_disp_2b <= reset_out | pixclk_locked_n;
		reset_disp_1b <= reset_disp_2b;
	end
	assign reset_disp = reset_disp_1b;

    dvi_disp #(
        .MMCM_CLKFBOUT_MULT(MMCM_CLKFBOUT_MULT),
        .MMCM_CLKIN_PERIOD(40.0),   // 25MHz input
        .MMCM_CLKOUT0_DIVIDE(MMCM_CLKOUT0_DIVIDE)
    ) dvi_disp_i (
        .clk25(clk25),
        .pclk_out(pixclk),
        .pclk_locked(pixclk_locked),
        .reset_in(~ARESETN),
        .reset_out(reset_out),
        .red_in(red),
        .green_in(green),
        .blue_in(blue),
        .hsync(~hsyncx),
        .vsync(~vsyncx),
        .display_enable(display_enable),
        .TMDS_tx_clk_p(TMDS_tx_clk_p),
        .TMDS_tx_clk_n(TMDS_tx_clk_n),
        .TMDS_tx_2_G_p(TMDS_tx_2_G_p),
        .TMDS_tx_2_G_n(TMDS_tx_2_G_n),
        .TMDS_tx_1_R_p(TMDS_tx_1_R_p),
        .TMDS_tx_1_R_n(TMDS_tx_1_R_n),
        .TMDS_tx_0_B_p(TMDS_tx_0_B_p),
        .TMDS_tx_0_B_n(TMDS_tx_0_B_n)
    );
    assign pixclk_locked_n = ~pixclk_locked;
endmodule

`default_nettype wire
