// axi_master_interface.v
//
// Read Only IP, 64 bit bus
//
// 2012/06/28

`default_nettype none

module axi_master_interface #
  (
		parameter integer C_M_AXI_THREAD_ID_WIDTH       = 1,
		parameter integer C_M_AXI_ADDR_WIDTH            = 32,
		parameter integer C_M_AXI_DATA_WIDTH            = 64,
		parameter integer C_M_AXI_AWUSER_WIDTH          = 1,
		parameter integer C_M_AXI_ARUSER_WIDTH          = 1,
		parameter integer C_M_AXI_WUSER_WIDTH           = 1,
		parameter integer C_M_AXI_RUSER_WIDTH           = 1,
		parameter integer C_M_AXI_BUSER_WIDTH           = 1,

		/* Disabling these parameters will remove any throttling.
		The resulting ERROR flag will not be useful */ 
		parameter integer C_M_AXI_SUPPORTS_WRITE         = 0,
		parameter integer C_M_AXI_SUPPORTS_READ         = 1
	)
	(
		// System Signals
		input wire 	      ACLK,
		input wire 	      ARESETN,

		// Master Interface Write Address
		output wire [C_M_AXI_THREAD_ID_WIDTH-1:0] M_AXI_AWID,
		output wire [C_M_AXI_ADDR_WIDTH-1:0]      M_AXI_AWADDR,
		output wire [8-1:0] 			 M_AXI_AWLEN,
		output wire [3-1:0] 			 M_AXI_AWSIZE,
		output wire [2-1:0] 			 M_AXI_AWBURST,
		output wire 				 M_AXI_AWLOCK,
		output wire [4-1:0] 			 M_AXI_AWCACHE,
		output wire [3-1:0] 			 M_AXI_AWPROT,
		// AXI3 output wire [4-1:0]                  M_AXI_AWREGION,
		output wire [4-1:0] 			 M_AXI_AWQOS,
		output wire [C_M_AXI_AWUSER_WIDTH-1:0] 	 M_AXI_AWUSER,
		output wire 				 M_AXI_AWVALID,
		input  wire 				 M_AXI_AWREADY,

		// Master Interface Write Data
		// AXI3 output wire [C_M_AXI_THREAD_ID_WIDTH-1:0]     M_AXI_WID,
		output wire [C_M_AXI_DATA_WIDTH-1:0] 	 M_AXI_WDATA,
		output wire [C_M_AXI_DATA_WIDTH/8-1:0] 	 M_AXI_WSTRB,
		output wire 				 M_AXI_WLAST,
		output wire [C_M_AXI_WUSER_WIDTH-1:0] 	 M_AXI_WUSER,
		output wire 				 M_AXI_WVALID,
		input  wire 				 M_AXI_WREADY,

		// Master Interface Write Response
		input  wire [C_M_AXI_THREAD_ID_WIDTH-1:0] 	 M_AXI_BID,
		input  wire [2-1:0] 			 M_AXI_BRESP,
		input  wire [C_M_AXI_BUSER_WIDTH-1:0] 	 M_AXI_BUSER,
		input  wire 				 M_AXI_BVALID,
		output wire 				 M_AXI_BREADY,

		// Master Interface Read Address
		output wire [C_M_AXI_THREAD_ID_WIDTH-1:0] 	 M_AXI_ARID,
		output reg  [C_M_AXI_ADDR_WIDTH-1:0] 	 M_AXI_ARADDR,
		output reg  [8-1:0] 			 M_AXI_ARLEN,
		output wire [3-1:0] 			 M_AXI_ARSIZE,
		output wire [2-1:0] 			 M_AXI_ARBURST,
		output wire [2-1:0] 			 M_AXI_ARLOCK,
		output wire [4-1:0] 			 M_AXI_ARCACHE,
		output wire [3-1:0] 			 M_AXI_ARPROT,
		// AXI3 output wire [4-1:0] 		 M_AXI_ARREGION,
		output wire [4-1:0] 			 M_AXI_ARQOS,
		output wire [C_M_AXI_ARUSER_WIDTH-1:0] 	 M_AXI_ARUSER,
		output wire 				 M_AXI_ARVALID,
		input  wire 				 M_AXI_ARREADY,

		// Master Interface Read Data 
		input  wire [C_M_AXI_THREAD_ID_WIDTH-1:0] 	 M_AXI_RID,
		input  wire [C_M_AXI_DATA_WIDTH-1:0] 	 M_AXI_RDATA,
		input  wire [2-1:0] 			 M_AXI_RRESP,
		input  wire 				 M_AXI_RLAST,
		input  wire [C_M_AXI_RUSER_WIDTH-1:0] 	 M_AXI_RUSER,
		input  wire 				 M_AXI_RVALID,
		output wire 				 M_AXI_RREADY,
		
		// bitmap_disp_engine Interface
		input	wire	bde_req,
		output	reg	bde_ack,
		input	wire	[7:0]	bde_arlen,
		input	wire	[31:0]	bde_address,
		output	reg		[63:0]	bde_data_out,
		output	reg		bde_data_valid
	);
	
	parameter	RESP_OKAY =		2'b00,
				RESP_EXOKAY =	2'b01,
				RESP_SLVERR =	2'b10,
				RESP_DECERR =	2'b11;
	
	reg		reset_1d, reset;
	
	parameter	idle_rd =			4'b0001,
				arvalid_assert =	4'b0010,
				data_read =			4'b0100,
				rd_tran_end =		4'b1000;
	reg		[3:0]	rdt_cs;
	
	reg		arvalid;
	reg		[63:0]	read_data;
	reg		rready;
	
	// ARESETN ‚ðACLK ‚Å“¯Šú‰»
	always @(posedge ACLK) begin
		reset_1d <= ~ARESETN;
		reset <= reset_1d;
	end
	
	// Write ‚Í–³‚µ
	assign	M_AXI_AWID = 0;
	assign	M_AXI_AWADDR = 0;
	assign	M_AXI_AWLEN = 0;
	assign	M_AXI_AWSIZE = 0;
	assign	M_AXI_AWBURST = 0;
	assign	M_AXI_AWLOCK = 0;
	assign	M_AXI_AWCACHE = 0;
	assign	M_AXI_AWPROT = 0;
	assign	M_AXI_AWQOS = 0;
	assign	M_AXI_AWUSER = 0;
	assign	M_AXI_AWVALID = 0;
	assign	M_AXI_WDATA = 0;
	assign	M_AXI_WSTRB = 0;
	assign	M_AXI_WLAST = 0;
	assign	M_AXI_WUSER = 0;
	assign	M_AXI_WVALID = 0;
	assign	M_AXI_BREADY = 0;

	// Read
	
	// AXI4ƒoƒX Read Transaction State Machine
	always @(posedge ACLK) begin
		if (reset) begin
			rdt_cs <= idle_rd;
			arvalid <= 1'b0;
			rready <= 1'b0;
		end else begin
			case (rdt_cs)
				idle_rd :
					if (bde_req) begin
						rdt_cs <= arvalid_assert;
						arvalid <= 1'b1;
					end
				arvalid_assert :
					if (M_AXI_ARREADY) begin
						rdt_cs <= data_read;
						arvalid <= 1'b0;
						rready <= 1'b1;
					end
				data_read :
					if (M_AXI_RLAST && M_AXI_RVALID) begin // I—¹
						rdt_cs <= rd_tran_end;
						rready <= 1'b0;
					end
				rd_tran_end :
					rdt_cs <= idle_rd;
			endcase
		end
	end
	assign M_AXI_ARVALID = arvalid;
	assign M_AXI_RREADY = rready;
	
	assign M_AXI_ARID = 0;
	
	// M_AXI_ARADDR ‚Ìˆ—
	always @(posedge ACLK) begin
		if (reset)
			M_AXI_ARADDR <= 0;
		else begin
			if (bde_req)
				M_AXI_ARADDR <= bde_address;
		end
	end
	
	// M_AXI_ARLEN ‚Ìˆ—
	always @(posedge ACLK) begin
		M_AXI_ARLEN <= bde_arlen;
	end
	
	assign M_AXI_ARSIZE = 3'b011;		// 8 Bytes in Transfer
	assign M_AXI_ARBURST = 2'b01;		// INCR
	assign M_AXI_ARLOCK = 2'b00;		// Normal Access
	assign M_AXI_ARCACHE = 4'b0011;	// Normal Non-cacheable Bufferable, Xilinx‚Ì„§
	assign M_AXI_ARPROT = 3'b000;		// Data access, Secure access, Unprivileged access
	assign M_AXI_ARQOS = 4'b0000;		// default
	assign M_AXI_ARUSER = 1'b0;
	
	// bde_ack ‚Ìˆ—
	always @(posedge ACLK) begin
		if (arvalid && M_AXI_ARREADY)
			bde_ack <= 1'b1;
		else
			bde_ack <= 1'b0;
	end
	
	// bde_data_out ‚Ìˆ—
	always @(posedge ACLK) begin
		bde_data_out <= M_AXI_RDATA;
	end
	
	// bde_data_valid ‚Ìˆ—
	always @(posedge ACLK) begin
		if (rready && M_AXI_RVALID)
			bde_data_valid <= 1'b1;
		else
			bde_data_valid <= 1'b0;
	end
	
endmodule

`default_nettype wire
