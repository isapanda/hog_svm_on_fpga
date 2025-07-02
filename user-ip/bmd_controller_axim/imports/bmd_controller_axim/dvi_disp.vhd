-- dvi_disp.vhd
-- Verilog版とは違ってDigilent 社のDVITransmitter.vhd を使用する
-- 2014/07/02 : hdmi_tx.vhd を使用した
-- 2014/07/23 : reset_out ポートを追加した
-- 2014/09/20 : pclk_locked ボートを追加した

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library UNISIM;
use UNISIM.VComponents.all;

entity dvi_disp is
	generic (
		MMCM_CLKFBOUT_MULT : real := 10.0;	-- VGA解像度 MCM VCO Freq 600MHz ~ 1200MHz
		MMCM_CLKIN_PERIOD : real := 40.0;	-- VGA ピクセルクロック周期
		MMCM_CLKOUT0_DIVIDE : real := 2.5	-- ピクセルクロックX10
	);
	port (
		clk25 :	in	std_logic;				-- 25MHz clock
		pclk_out : out std_logic;			-- pixclk output
		pclk_locked :	out std_logic;		-- pixclk locked
		reset_in :	in 	std_logic;			-- active high
		reset_out : out	std_logic;			-- active high
		red_in :	in	std_logic_vector(7 downto 0);	-- RED入力
		green_in :	in	std_logic_vector(7 downto 0);	-- GREEN入力
		blue_in :	in	std_logic_vector(7 downto 0);	-- BLUE入力
		hsync :		in	std_logic;
		vsync :		in	std_logic;
		display_enable :	in std_logic;				-- 表示が有効
		TMDS_tx_clk_p :	out	std_logic;					-- Clock
		TMDS_tx_clk_n :	out	std_logic;
		TMDS_tx_2_G_p :	out	std_logic;					-- Green
		TMDS_tx_2_G_n :	out	std_logic;
		TMDS_tx_1_R_p :	out	std_logic;					-- Red
		TMDS_tx_1_R_n :	out	std_logic;
		TMDS_tx_0_B_p :	out	std_logic;					-- Blue
		TMDS_tx_0_B_n :	out	std_logic
	);
end dvi_disp;

architecture RTL of dvi_disp is
component MMCME2_BASE
	generic (
	  BANDWIDTH : string := "OPTIMIZED";
	  CLKFBOUT_MULT_F : real := 5.000;
	  CLKFBOUT_PHASE : real := 0.000;
	  CLKIN1_PERIOD : real := 0.000;
	  CLKOUT0_DIVIDE_F : real := 1.000;
	  CLKOUT0_DUTY_CYCLE : real := 0.500;
	  CLKOUT0_PHASE : real := 0.000;
	  CLKOUT1_DIVIDE : integer := 1;
	  CLKOUT1_DUTY_CYCLE : real := 0.500;
	  CLKOUT1_PHASE : real := 0.000;
	  CLKOUT2_DIVIDE : integer := 1;
	  CLKOUT2_DUTY_CYCLE : real := 0.500;
	  CLKOUT2_PHASE : real := 0.000;
	  CLKOUT3_DIVIDE : integer := 1;
	  CLKOUT3_DUTY_CYCLE : real := 0.500;
	  CLKOUT3_PHASE : real := 0.000;
	  CLKOUT4_CASCADE : boolean := FALSE;
	  CLKOUT4_DIVIDE : integer := 1;
	  CLKOUT4_DUTY_CYCLE : real := 0.500;
	  CLKOUT4_PHASE : real := 0.000;
	  CLKOUT5_DIVIDE : integer := 1;
	  CLKOUT5_DUTY_CYCLE : real := 0.500;
	  CLKOUT5_PHASE : real := 0.000;
	  CLKOUT6_DIVIDE : integer := 1;
	  CLKOUT6_DUTY_CYCLE : real := 0.500;
	  CLKOUT6_PHASE : real := 0.000;
	  DIVCLK_DIVIDE : integer := 1;
	  REF_JITTER1 : real := 0.010;
	  STARTUP_WAIT : boolean := FALSE
	);

	port (
	  CLKFBOUT             : out std_ulogic;
	  CLKFBOUTB            : out std_ulogic;
	  CLKOUT0              : out std_ulogic;
	  CLKOUT0B             : out std_ulogic;
	  CLKOUT1              : out std_ulogic;
	  CLKOUT1B             : out std_ulogic;
	  CLKOUT2              : out std_ulogic;
	  CLKOUT2B             : out std_ulogic;
	  CLKOUT3              : out std_ulogic;
	  CLKOUT3B             : out std_ulogic;
	  CLKOUT4              : out std_ulogic;
	  CLKOUT5              : out std_ulogic;
	  CLKOUT6              : out std_ulogic;
	  LOCKED               : out std_ulogic;
	  CLKFBIN              : in std_ulogic;
	  CLKIN1               : in std_ulogic;
	  PWRDWN               : in std_ulogic;
	  RST                  : in std_ulogic      
	);
end component;

component hdmi_tx
    generic (
        C_RED_WIDTH : integer   := 8;
        C_GREEN_WIDTH : integer  := 8;
        C_BLUE_WIDTH : integer  := 8
    );    
	Port (
		PXLCLK_I : in STD_LOGIC;
		PXLCLK_5X_I : in STD_LOGIC;
		LOCKED_I : in STD_LOGIC;
		RST_I : in STD_LOGIC;
		
		--VGA
		VGA_HS : in std_logic;
		VGA_VS : in std_logic;
		VGA_DE : in std_logic;
		VGA_R : in std_logic_vector(C_RED_WIDTH-1 downto 0);
		VGA_G : in std_logic_vector(C_GREEN_WIDTH-1 downto 0);
		VGA_B : in std_logic_vector(C_BLUE_WIDTH-1 downto 0);

		--HDMI
		HDMI_CLK_P : out  STD_LOGIC;
		HDMI_CLK_N : out  STD_LOGIC;
		HDMI_D2_P : out  STD_LOGIC;
		HDMI_D2_N : out  STD_LOGIC;
		HDMI_D1_P : out  STD_LOGIC;
		HDMI_D1_N : out  STD_LOGIC;
		HDMI_D0_P : out  STD_LOGIC;
		HDMI_D0_N : out  STD_LOGIC
	);
			  
end component;

component BUFG
  port (
     O : out std_ulogic;
     I : in std_ulogic
  );
end component;

component BUFMRCE
  generic (
     CE_TYPE : string := "SYNC";
     INIT_OUT : integer := 0;
     IS_CE_INVERTED : std_ulogic := '0'
  );
  port (
     O : out std_ulogic;
     CE : in std_ulogic;
     I : in std_ulogic
  );
end component;
attribute BOX_TYPE of
  BUFMRCE : component is "PRIMITIVE";

component BUFR
  generic (
     BUFR_DIVIDE : string := "BYPASS";
     SIM_DEVICE : string := "VIRTEX4"
  );
  port (
     O : out std_ulogic;
     CE : in std_ulogic;
     CLR : in std_ulogic;
     I : in std_ulogic
  );
end component;
attribute BOX_TYPE of
  BUFR : component is "PRIMITIVE";
  
 component BUFIO
    port (
       O : out std_ulogic;
       I : in std_ulogic
    );
  end component;
  attribute BOX_TYPE of
    BUFIO : component is "PRIMITIVE";

signal pixel_clkx5 : std_logic;
signal mmcm_locked : std_logic;
signal pclk_buf, pclkx5_buf : std_logic;
signal mmcm_locked_n : std_logic;
signal mmc_fb_in, mmc_fb_out : std_logic;
signal pclk_buf_out : std_logic;

begin
	MMCM_BASE_PIXEL : MMCME2_BASE generic map (
		BANDWIDTH			=> "OPTIMIZED",
    	CLKOUT4_CASCADE     => FALSE,
    	STARTUP_WAIT        => FALSE,
   		CLKFBOUT_MULT_F		=> MMCM_CLKFBOUT_MULT,
		CLKIN1_PERIOD		=> MMCM_CLKIN_PERIOD,
		CLKOUT0_DIVIDE_F	=> MMCM_CLKOUT0_DIVIDE,
		DIVCLK_DIVIDE		=> 1
	) port map (
		CLKFBOUT	=> mmc_fb_out,
		CLKOUT0		=> pixel_clkx5,
		LOCKED		=> mmcm_locked,
		CLKFBIN		=> mmc_fb_in,
		CLKIN1		=> clk25,
		PWRDWN		=> '0',
		RST			=> '0'
	);
	mmcm_locked_n <= not mmcm_locked;
	
	mmc_fb_in <= mmc_fb_out;
	-- BUF_FB : BUFG port map(
	-- 	I => mmc_fb_out,
	-- 	O => mmc_fb_in
	-- );

	BUFIO_pixel_clkx5 : BUFIO port map (
		O	=> pclkx5_buf,
		I	=> pixel_clkx5
	);
	
	BUFR_pixel_clk_io : BUFR generic map(
		BUFR_DIVIDE => "5",
		SIM_DEVICE => "7SERIES"
	) port map (
		O	=> pclk_buf,
		CE  => '1',
		CLR => mmcm_locked_n,
		I	=> pixel_clkx5
	);
	
	CLK_OUT_BUFG : bufg port map (
		O	=> pclk_buf_out,
		I	=> pclk_buf
	);
	pclk_out <= pclk_buf_out;
	pclk_locked <= mmcm_locked;

	hdmi_tx_i : hdmi_tx generic map (
		C_RED_WIDTH		=> 8,
		C_GREEN_WIDTH	=> 8,
		C_BLUE_WIDTH	=> 8
	) port map (
		PXLCLK_I	=> pclk_buf_out,
		PXLCLK_5X_I	=> pclkx5_buf,
		LOCKED_I	=> mmcm_locked,
		RST_I		=> reset_in,
		VGA_HS		=> hsync,
		VGA_VS		=> vsync,
		VGA_DE		=> display_enable,
		VGA_R		=> red_in,
		VGA_G		=> green_in,
		VGA_B		=> blue_in,
		HDMI_CLK_P	=> TMDS_tx_clk_p,
		HDMI_CLK_N	=> TMDS_tx_clk_n,
		HDMI_D2_P	=> TMDS_tx_2_G_p,
		HDMI_D2_N	=> TMDS_tx_2_G_n,
		HDMI_D1_P	=> TMDS_tx_1_R_p,
		HDMI_D1_N	=> TMDS_tx_1_R_n,
		HDMI_D0_P	=> TMDS_tx_0_B_p,
		HDMI_D0_N	=> TMDS_tx_0_B_n
	);
end RTL;

