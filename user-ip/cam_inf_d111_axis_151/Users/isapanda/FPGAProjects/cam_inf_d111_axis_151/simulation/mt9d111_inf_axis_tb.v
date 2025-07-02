`default_nettype none

`timescale 100ps / 1ps

// mt9d111_inf_axis_tb.v
// 2015/05/11
//

module mt9d111_inf_axis_tb;
	parameter integer C_S_AXI_LITE_ADDR_WIDTH = 9; // Address width of the AXI Lite Interface
	parameter integer C_S_AXI_LITE_DATA_WIDTH = 32; // Data width of the AXI Lite Interface

	parameter integer C_M_AXIS_DATA_WIDTH = 32; // AXI4 Stream Master Interface
	
	parameter DELAY = 1;
	
	// Inputs
	wire ACLK;
	wire ARESETN;
	wire pclk_from_pll;
	wire pclk;
	wire href;
	wire vsync;
	wire [7:0] cam_data;
	wire m_axis_tready;

	// Outputs
	wire xck;
	wire standby;
	wire pfifo_overflow;
	wire pfifo_underflow;
	wire [C_M_AXIS_DATA_WIDTH-1:0] m_axis_tdata;
	wire [(C_M_AXIS_DATA_WIDTH/8)-1:0] m_axis_tstrb;
	wire m_axis_tvalid;
	wire m_axis_tlast;
	wire m_axis_tuser;

	// AXI Lite Write Address Channel
	reg										s_axi_lite_awvalid = 1'b0;
	wire									s_axi_lite_awready;
	reg		[C_S_AXI_LITE_ADDR_WIDTH-1: 0]	s_axi_lite_awaddr = 0;
	reg		[3-1:0]							s_axi_lite_awport = 1'b0;

	// AXI Lite Write Data Channel
	reg										s_axi_lite_wvalid =1'b0;
	wire									s_axi_lite_wready;
	reg		[C_S_AXI_LITE_DATA_WIDTH-1: 0]	s_axi_lite_wdata = 0;
	
	// AXI Lite Write Response Channel
	wire	[1:0]							s_axi_lite_bresp;
	wire									s_axi_lite_bvalid;
	reg										s_axi_lite_bready = 1'b0;

	// AXI Lite Read Address Channel
	reg										s_axi_lite_arvalid = 1'b0;
	wire									s_axi_lite_arready;
	reg		[C_S_AXI_LITE_ADDR_WIDTH-1: 0]	s_axi_lite_araddr = 1'b0;
	reg		[3-1:0]							s_axi_lite_arport = 0;
	
	// AXI Lite Read Data Channel
	wire									s_axi_lite_rvalid;
	reg										s_axi_lite_rready = 1'b0;
	wire	[C_S_AXI_LITE_DATA_WIDTH-1: 0]	s_axi_lite_rdata;
	wire	[1:0]							s_axi_lite_rresp;

	integer i;

	// Instantiate the Unit Under Test (UUT)
	mt9d111_inf_axis # (
		.C_M_AXIS_DATA_WIDTH(C_M_AXIS_DATA_WIDTH)
	) uut (
		.s_axi_lite_aclk(ACLK),
		.m_axis_aclk(ACLK), 
		.axi_resetn(ARESETN), 
		
		.s_axi_lite_awvalid(s_axi_lite_awvalid),
		.s_axi_lite_awready(s_axi_lite_awready),
		.s_axi_lite_awaddr(s_axi_lite_awaddr),
		//.s_axi_lite_awport(s_axi_lite_awport),
		.s_axi_lite_wvalid(s_axi_lite_wvalid),
		.s_axi_lite_wready(s_axi_lite_wready),
		.s_axi_lite_wdata(s_axi_lite_wdata),
		.s_axi_lite_bresp(s_axi_lite_bresp),
		.s_axi_lite_bvalid(s_axi_lite_bvalid),
		.s_axi_lite_bready(s_axi_lite_bready),
		.s_axi_lite_arvalid(s_axi_lite_arvalid),
		.s_axi_lite_arready(s_axi_lite_arready),
		.s_axi_lite_araddr(s_axi_lite_araddr),
		//.s_axi_lite_arport(s_axi_lite_arport),
		.s_axi_lite_rvalid(s_axi_lite_rvalid),
		.s_axi_lite_rready(s_axi_lite_rready),
		.s_axi_lite_rdata(s_axi_lite_rdata),
		.s_axi_lite_rresp(s_axi_lite_rresp),

		.m_axis_tdata(m_axis_tdata),
		.m_axis_tstrb(m_axis_tstrb),
		.m_axis_tvalid(m_axis_tvalid),
		.m_axis_tready(m_axis_tready),
		.m_axis_tlast(m_axis_tlast),
		.m_axis_tuser(m_axis_tuser),
		
		.pclk_from_pll(pclk_from_pll), 
		.pclk(pclk), 
		.xck(xck), 
		.href(href), 
		.vsync(vsync), 
		.cam_data(cam_data), 
		.standby(standby), 
		.pfifo_overflow(pfifo_overflow), 
		.pfifo_underflow(pfifo_underflow)
	);
	assign m_axis_tready = 1'b1;

	// ACLK のインスタンス
	clk_gen #(
		.CLK_PERIOD(100),	// 10nsec, 100MHz
		.CLK_DUTY_CYCLE(0.5),
		.CLK_OFFSET(0),
		.START_STATE(1'b0)
	) ACLKi (
		.clk_out(ACLK)
	);

	// pclk_from_pll のインスタンス
	clk_gen #(
		.CLK_PERIOD(278),	// 27.8nsec, 約36MHz
		.CLK_DUTY_CYCLE(0.5),
		.CLK_OFFSET(0),
		.START_STATE(1'b0)
	) pclk_from_pll_i (
		.clk_out(pclk_from_pll)
	);

	// reset_gen のインスタンス
	reset_gen #(
		.RESET_STATE(1'b0),
		.RESET_TIME(1000)	// 100nsec
	) RESETi (
		.reset_out(ARESETN)
	);

	// MT9D111 モデル
	mt9d111_model #(
		// .HORIZONTAL_PIXELS(800),
		// .VERTICAL_LINES(600),
		// .HBLANK_REG(174),
		// .VBLANK_REG(16),
		.HORIZONTAL_PIXELS(50),
		.VERTICAL_LINES(10),
		.HBLANK_REG(10),
		.VBLANK_REG(5),
		.PCLK_DELAY(1)
	) mt9d111_model_i (
		.xck(xck),
		.pclk(pclk),
		.href(href),
		.vsync(vsync),
		.d(cam_data),
		.scl(1'b1),
		.sda(),
		.standby(standby)
	);

	initial begin
		// Initialize Inputs
		s_axi_lite_awaddr = 0;
		s_axi_lite_awport = 0;
		s_axi_lite_wvalid = 0;
		s_axi_lite_wdata = 0;
		s_axi_lite_wvalid = 0;
		s_axi_lite_bready = 0;
		s_axi_lite_araddr = 0;
		s_axi_lite_arport = 0;
		s_axi_lite_arvalid = 0;
		s_axi_lite_rready = 0;

		// Wait Reset rising edge
		@(posedge ARESETN);
		
        for (i=0; i<10; i=i+1) begin
			@(posedge ACLK);    // 次のクロックへ
			#DELAY;
		end
		
		// Add stimulus here
		@(posedge ACLK);    // 次のクロックへ
		#DELAY;
		AXI_MASTER_WADC1(32'h0000_0000, 32'h1200_0000);
		@(posedge ACLK);    // 次のクロックへ
		#DELAY;
		AXI_MASTER_RADC1(32'h0000_0000);
		#DELAY;
		
		// @(posedge ACLK);    // 次のクロックへ		
		// #DELAY;
		// AXI_MASTER_WADC2(32'h0000_0004, 32'h0000_0001);	// one_shot mode
		// @(posedge ACLK);    // 次のクロックへ		
		// #DELAY;
		// AXI_MASTER_RADC2(32'h0000_0004);
		
		// @(posedge ACLK);    // 次のクロックへ		
  //       #DELAY;
  //       AXI_MASTER_WADC2(32'h0000_0004, 32'h0000_0003); // one_shot trigger
  //       @(posedge ACLK);    // 次のクロックへ        
  //       #DELAY;
  //       AXI_MASTER_RADC2(32'h0000_0004);
        
		// @(posedge ACLK);    // 次のクロックへ		
  //       #DELAY;
  //       AXI_MASTER_WADC2(32'h0000_0004, 32'h0000_0003); // one_shot trigger
  //       @(posedge ACLK);    // 次のクロックへ        
  //       #DELAY;
  //       AXI_MASTER_RADC2(32'h0000_0004);
	end
			
	// Write Transcation 1
	task AXI_MASTER_WADC1;
		input	[C_S_AXI_LITE_ADDR_WIDTH-1:0]	awaddr;
		input	[C_S_AXI_LITE_DATA_WIDTH-1:0]	wdata;
		begin
			s_axi_lite_awaddr	= awaddr;
			s_axi_lite_awvalid	= 1'b1;
			
			@(posedge ACLK);    // 次のクロックへ
			#DELAY;
			
			s_axi_lite_awvalid = 1'b0;
			s_axi_lite_wdata = wdata;
			s_axi_lite_wvalid = 1'b1;
			@(posedge ACLK);    // 次のクロックへ, s_axi_lite_wready は常に 1
			
			#DELAY;
			s_axi_lite_wvalid = 1'b0;
			s_axi_lite_bready = 1'b1;
			
			@(posedge ACLK);    // 次のクロックへ
			#DELAY;
				
			s_axi_lite_bready = 1'b0;
		end
	endtask

	// Write Transcation 2
	task AXI_MASTER_WADC2;
		input	[C_S_AXI_LITE_ADDR_WIDTH-1:0]	awaddr;
		input	[C_S_AXI_LITE_DATA_WIDTH-1:0]	wdata;
		begin
			s_axi_lite_awaddr	= awaddr;
			s_axi_lite_awvalid	= 1'b1;
			
			@(posedge ACLK);    // 次のクロックへ
			#DELAY;
			
			s_axi_lite_awvalid = 1'b0;
			s_axi_lite_wdata = wdata;
			s_axi_lite_wvalid = 1'b1;
			@(posedge ACLK);    // 次のクロックへ, s_axi_lite_wready は常に 1
			
			#DELAY;
			s_axi_lite_wvalid = 1'b0;		
			@(posedge ACLK);    // 次のクロックへ
			
			#DELAY;		
			s_axi_lite_bready = 1'b1;
			
			@(posedge ACLK);    // 次のクロックへ
			#DELAY;
				
			s_axi_lite_bready = 1'b0;
		end
	endtask
	
	// Read Transcation 1    
	task AXI_MASTER_RADC1;
		input    [31:0]    araddr;
		begin
			s_axi_lite_araddr    = araddr;
			s_axi_lite_arvalid     = 1'b1;
			@(posedge ACLK);    // 次のクロックへ
			#DELAY;
			
			s_axi_lite_araddr    = 0;
			s_axi_lite_arvalid     = 1'b0;
			s_axi_lite_rready = 1'b1;

			@(posedge ACLK);    // 次のクロックへ
			#DELAY;

			s_axi_lite_rready = 1'b0;
		end
	endtask
	
	// Read Transcation 2   
	task AXI_MASTER_RADC2;
		input    [31:0]    araddr;
		begin
			s_axi_lite_araddr    = araddr;
			s_axi_lite_arvalid     = 1'b1;
			@(posedge ACLK);    // 次のクロックへ
			#DELAY;
			
			s_axi_lite_araddr    = 0;
			s_axi_lite_arvalid     = 1'b0;
			@(posedge ACLK);    // 次のクロックへ
			#DELAY;

			s_axi_lite_rready = 1'b1;

			@(posedge ACLK);    // 次のクロックへ
			#DELAY;

			s_axi_lite_rready = 1'b0;
		end
	endtask
	
endmodule

module clk_gen #(
	parameter 		CLK_PERIOD = 100,
    parameter real	CLK_DUTY_CYCLE = 0.5,
    parameter		CLK_OFFSET = 0,
	parameter		START_STATE	= 1'b0 )
(
	output	reg		clk_out
);
    begin
		initial begin
			#CLK_OFFSET;
			forever
			begin
				clk_out = START_STATE;
				#(CLK_PERIOD-(CLK_PERIOD*CLK_DUTY_CYCLE)) clk_out = ~START_STATE;
				#(CLK_PERIOD*CLK_DUTY_CYCLE);
			end
		end
    end
endmodule

module reset_gen #(
	parameter	RESET_STATE = 1'b1,
	parameter	RESET_TIME = 100 )
(
	output	reg		reset_out
);
	begin
		initial begin
			reset_out = RESET_STATE;
			#RESET_TIME;
			reset_out = ~RESET_STATE;
		end
	end
endmodule

`default_nettype wire
