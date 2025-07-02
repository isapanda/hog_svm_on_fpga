-------------------------------------------------------------------------------
--
-- AXI Stream
--
-- VHDL-Standard:   VHDL'93
----------------------------------------------------------------------------
--
-- Structure:
--   mt9d111_inf_axims
--
----------------------------------------------------------------------------
--
-- 2014/11/07 : AXI4 Lite Slave を追加
-- 2014/11/08 : one_shot_reg を実装。
-- オフセット0番地：　フレーム・バッファの先頭アドレス(fb_start_address)
-- オフセット4番地：　0 ビット目が 0 の時動画、0 ビット目に 1 の時に、ワンショットで取得した1フレームのカメラ画像を表示(one_shot_reg)
--　　　　　　　　　　　　1 ビット目に 1 を Write した時に、ワンショットで1フレームの画像をフレーム・バッファに保存
-- 2015/05/09 : AXI4 Master から AXI4 Master Stream にインターフェースを変更、generic map, port map は ar37425\axi_stream_v1_00_a\hdl\vhdl の axi_stream.vhd から引用した
-- 				AXI4 Stream なので、fb_start_address は使用しない。そこに書き込まれたというスタート信号だけを使用する


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

--library unisim;
--use unisim.vcomponents.all;

entity mt9d111_inf_axis is
  generic(
	-- AXI4 Lite Slave Interface
	C_S_AXI_LITE_ADDR_WIDTH         : integer   	:= 9; -- Address width of the AXI Lite Interface
	C_S_AXI_LITE_DATA_WIDTH         : integer   	:= 32; -- Data width of the AXI Lite Interface

	-- AXI4 Stream Master Interface
    C_M_AXIS_DATA_WIDTH : integer range 32 to 256 := 32  -- Master AXI Stream Data Width  
  );
  port (
    -- Global Ports
	s_axi_lite_aclk				: in   std_logic;
    m_axis_aclk    				: in std_logic;
    axi_resetn 					: in std_logic;

    -- Master Stream Ports
	-- m_axis_aresetn : out std_logic;
    m_axis_tdata   : out std_logic_vector(C_M_AXIS_DATA_WIDTH-1 downto 0);
    m_axis_tstrb   : out std_logic_vector((C_M_AXIS_DATA_WIDTH/8)-1 downto 0);
    m_axis_tvalid  : out std_logic;
    m_axis_tready  : in  std_logic;
    m_axis_tlast   : out std_logic;
    m_axis_tuser   : out std_logic_vector(0 downto 0);

    -- AXI Lite Slave Ports
	s_axi_lite_awvalid          : in  std_logic;
	s_axi_lite_awready          : out std_logic;
	s_axi_lite_awaddr           : in  std_logic_vector(C_S_AXI_LITE_ADDR_WIDTH-1 downto 0);

	-- AXI Lite Write Data Channel --
	s_axi_lite_wvalid           : in  std_logic;
	s_axi_lite_wready           : out std_logic;
	s_axi_lite_wdata            : in  std_logic_vector(C_S_AXI_LITE_DATA_WIDTH-1 downto 0);

	-- AXI Lite Write Response Channel --
	s_axi_lite_bresp            : out std_logic_vector(1 downto 0);
	s_axi_lite_bvalid           : out std_logic;
	s_axi_lite_bready           : in  std_logic;

	-- AXI Lite Read Address Channel --
	s_axi_lite_arvalid          : in  std_logic;
	s_axi_lite_arready          : out std_logic;
	s_axi_lite_araddr           : in  std_logic_vector(C_S_AXI_LITE_ADDR_WIDTH-1 downto 0);
	
	-- AXI Lite Read Data Channel --
	s_axi_lite_rvalid           : out std_logic;
	s_axi_lite_rready           : in  std_logic;
	s_axi_lite_rdata            : out std_logic_vector(C_S_AXI_LITE_DATA_WIDTH-1 downto 0);
	s_axi_lite_rresp            : out std_logic_vector(1 downto 0);
	
    -- MT9D111 Camera Interface
	pclk_from_pll	: in	std_logic;	-- PLLからMT9D111のxck に出力するクロック
	pclk			: in 	std_logic;	-- MT9D111からのピクセルクロック入力
	xck				: out	std_logic;	-- MT9D111へのピクセルクロック出力
	href			: in 	std_logic;
	vsync			: in	std_logic;
	cam_data		: in	std_logic_vector(7 downto 0);
	standby			: out	std_logic;	-- STANDBY出力（ディスエーブル、0固定）
	pfifo_overflow	: out	std_logic;	-- pfifo overflow
	pfifo_underflow	: out	std_logic	-- pfifo underflow
);

end mt9d111_inf_axis;

-------------------------------------------------------------------------------
-- Architecture
-------------------------------------------------------------------------------
architecture implementation of mt9d111_inf_axis is

constant	ONE_SHOT_PULSE_LENGTH : integer := 20;	-- 1ショットパルスの長さのAXI Lite Slave ACLKのクロック数をセット

signal resetn_1d, resetn_2d, reset : std_logic;
signal init_done_1d, init_done_2d : std_logic;
signal resetn_1dp, resetn_2dp : std_logic;
signal init_done_1dp, init_done_2dp : std_logic;
signal preset_1d, preset_2d, preset : std_logic;
signal pfifo_empty		: std_logic;
signal pfifo_almost_empty	: std_logic;
signal pfifo_rd_data_count	: std_logic_vector(9 downto 0);
signal pfifo_rd_dcount_dec : unsigned(9 downto 0);
signal pfifo_rd_en : std_logic;
signal ACLK : std_logic := '0';
signal one_shot_state : std_logic;
signal one_shot_trigger : std_logic;
signal init_done : std_logic;
signal pfifo_dout : std_logic_vector(33 downto 0);

component mt9d111_cam_cont 
	port(
		aclk			: in std_logic;
		areset			: in std_logic;
		pclk			: in std_logic;
		preset			: in std_logic;
		pclk_from_pll	: in std_logic;
		xclk			: out std_logic;
		line_valid		: in std_logic;
		frame_valid		: in std_logic;
		cam_data		: in std_logic_vector(7 downto 0);
		standby			: out std_logic;
		pfifo_rd_en		: in std_logic;
		pfifo_dout		: out std_logic_vector(33 downto 0); -- frame data start signal + data[31:0]
		pfifo_empty		: out std_logic;
		pfifo_almost_empty		: out std_logic;
		pfifo_rd_data_count	: out std_logic_vector(9 downto 0);
		pfifo_overflow		: out std_logic;
		pfifo_underflow		: out std_logic;
		one_shot_state			: in std_logic;	-- 1フレーム分取り込んだカメラ画像を保持する
		one_shot_trigger		: in std_logic		-- 1フレーム分のカメラ画像取り込みのトリガー、1クロックパルス
	); 
end component;

component mt9d111_axi_lite_slave generic (
		C_S_AXI_LITE_ADDR_WIDTH         : integer range 9 to 9    	:= 9; -- Address width of the AXI Lite Interface
		C_S_AXI_LITE_DATA_WIDTH         : integer range 32 to 32    	:= 32; -- Data width of the AXI Lite Interface
		
		C_DISPLAY_START_ADDRESS			: std_logic_vector(31 downto 0) := x"1A000000";
		ONE_SHOT_PULSE_LENGTH			: integer 					:= 20	-- 1ショットパルスの長さのAXI Lite Slave ACLKのクロック数をセット
	);
	port(
		-- Clock and Reset
		s_axi_lite_aclk				: in   std_logic;
		axi_resetn					: in   std_logic;
		
		-------------------------------
		-- AXI4 Lite Slave Interface --
		-------------------------------
		-- AXI Lite Write Address Channel --
		s_axi_lite_awvalid          : in  std_logic;
		s_axi_lite_awready          : out std_logic;
		s_axi_lite_awaddr           : in  std_logic_vector(C_S_AXI_LITE_ADDR_WIDTH-1 downto 0);
		
		-- AXI Lite Write Data Channel --
		s_axi_lite_wvalid           : in  std_logic;
		s_axi_lite_wready           : out std_logic;
		s_axi_lite_wdata            : in  std_logic_vector(C_S_AXI_LITE_DATA_WIDTH-1 downto 0);

		-- AXI Lite Write Response Channel  --
		s_axi_lite_bresp            : out std_logic_vector(1 downto 0);
		s_axi_lite_bvalid           : out std_logic;
		s_axi_lite_bready           : in  std_logic;

		-- AXI Lite Read Address Channel --
		s_axi_lite_arvalid          : in  std_logic;
		s_axi_lite_arready          : out std_logic;
		s_axi_lite_araddr           : in  std_logic_vector(C_S_AXI_LITE_ADDR_WIDTH-1 downto 0);
	
		-- AXI Lite Read Data Channel
		s_axi_lite_rvalid           : out std_logic;
		s_axi_lite_rready           : in  std_logic;
		s_axi_lite_rdata            : out std_logic_vector(C_S_AXI_LITE_DATA_WIDTH-1 downto 0);
		s_axi_lite_rresp            : out std_logic_vector(1 downto 0);
		
		fb_start_address			: out std_logic_vector(31 downto 0);	-- Frame Buffer のスタートアドレス
		init_done                   : out std_logic;  -- fb_start_address に書き込まれた
		one_shot_state				: out std_logic;	-- 1フレーム分取り込んだカメラ画像を保持する
		one_shot_trigger			: out std_logic		-- 1フレーム分のカメラ画像取り込みのトリガー、1クロックパルス
	);
end component;

begin
	ACLK <= m_axis_aclk;
	
	-- mt9d111_axi_lite_slave のインスタンス
	mt9d111_axi_lite_slave_i : mt9d111_axi_lite_slave generic map(
		C_S_AXI_LITE_ADDR_WIDTH	=> C_S_AXI_LITE_ADDR_WIDTH,
		C_S_AXI_LITE_DATA_WIDTH	=> C_S_AXI_LITE_DATA_WIDTH,
		
		C_DISPLAY_START_ADDRESS	=> (others => '0'),
		ONE_SHOT_PULSE_LENGTH	=> ONE_SHOT_PULSE_LENGTH
	) port map (
		s_axi_lite_aclk		=> s_axi_lite_aclk,
		axi_resetn			=> axi_resetn,
		s_axi_lite_awvalid	=> s_axi_lite_awvalid,
		s_axi_lite_awready	=> s_axi_lite_awready,
		s_axi_lite_awaddr	=> s_axi_lite_awaddr,
		s_axi_lite_wvalid	=> s_axi_lite_wvalid,
		s_axi_lite_wready	=> s_axi_lite_wready,
		s_axi_lite_wdata	=> s_axi_lite_wdata,
		s_axi_lite_bresp	=> s_axi_lite_bresp,
		s_axi_lite_bvalid	=> s_axi_lite_bvalid,
		s_axi_lite_bready	=> s_axi_lite_bready,
		s_axi_lite_arvalid	=> s_axi_lite_arvalid,
		s_axi_lite_arready	=> s_axi_lite_arready,
		s_axi_lite_araddr	=> s_axi_lite_araddr,
		s_axi_lite_rvalid	=> s_axi_lite_rvalid,
		s_axi_lite_rready	=> s_axi_lite_rready,
		s_axi_lite_rdata	=> s_axi_lite_rdata,
		s_axi_lite_rresp	=> s_axi_lite_rresp,
		fb_start_address	=> open,
		init_done			=> init_done,
		one_shot_state		=> one_shot_state,
		one_shot_trigger	=> one_shot_trigger
	);
		
    -- axi_resetn をACLK で同期化
	process (ACLK) begin
		if ACLK'event and ACLK='1' then 
		    resetn_1d <= axi_resetn;
		    resetn_2d <= resetn_1d;
		    init_done_1d <= init_done;
		    init_done_2d <= init_done_1d;
		    reset <= not resetn_2d or not init_done_2d;
		end if;
	end process;
	
	-- axi_resetn をpclk で同期化
	process(pclk) begin
		if pclk'event and pclk='1' then
		    resetn_1dp <= axi_resetn;
            resetn_2dp <= resetn_1dp;
            init_done_1dp <= init_done;
            init_done_2dp <= init_done_1dp;
			preset <= not resetn_2dp or not init_done_2dp;
		end if;
	end process;
		
	pfifo_rd_en <= not pfifo_empty and m_axis_tready;
	mt9d111_cam_cont_i : mt9d111_cam_cont port map(
		aclk				=> ACLK,
		areset				=> reset,
		pclk				=> pclk,
		preset				=> preset,
		pclk_from_pll		=> pclk_from_pll,
		xclk				=> xck,
		line_valid			=> href,
		frame_valid			=> vsync,
		cam_data			=> cam_data,
		standby				=> standby,
		pfifo_rd_en			=> pfifo_rd_en,
		pfifo_dout			=> pfifo_dout, -- frame start data signal + tlast + data[31:0]
		pfifo_empty			=> pfifo_empty,
		pfifo_almost_empty	=> pfifo_almost_empty,
		pfifo_rd_data_count	=> pfifo_rd_data_count,
		pfifo_overflow		=> pfifo_overflow,
		pfifo_underflow		=> pfifo_underflow,
		one_shot_state		=> one_shot_state,
		one_shot_trigger	=> one_shot_trigger
	);
	m_axis_tdata <= pfifo_dout(31 downto 0);
	m_axis_tuser(0) <= pfifo_dout(32);
	m_axis_tlast <= pfifo_dout(33);
	m_axis_tvalid <= not pfifo_empty;
	pfifo_rd_en <= not pfifo_empty and m_axis_tready;
	m_axis_tstrb <= (others => '1');

end implementation;
