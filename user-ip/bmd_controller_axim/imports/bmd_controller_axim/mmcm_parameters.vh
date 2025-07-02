// mmcm_parameters.vh
//
// by marsee
//
// 25MHz clock input
//
// 2014/07/26 : MMCM parameters for video by marsee
//

// MMCM_CLKFBOUT_MULT
parameter MMCM_CLKFBOUT_MULT = (RESOLUTION=="VGA") ?    30.0 :  // VGA (VCO Freq = 750MHz)
                (RESOLUTION=="SVGA") ?                  24.0 :  // SVGA (VCO Freq = 600MHz)
                (RESOLUTION=="XGA") ?                   26.0 :  // XGA (VCO Freq = 650MHz)
                (RESOLUTION=="SXGA") ?                  43.25 : // SXGA (VCO Freq = 1081.25MHz)
                (RESOLUTION=="HD") ?                    29.75 : 29.75;  // HD (VCO Freq = 743.75MHz)

// MMCM_CLKOUT0_DIVIDE
parameter MMCM_CLKOUT0_DIVIDE = (RESOLUTION=="VGA") ?   6.0 :  // 25MHz x 5 = 125MHz
                (RESOLUTION=="SVGA") ?                  3.0 :              // 40MHz x 5 = 200MHz
                (RESOLUTION=="XGA") ?                   2.0 :              // 65MHz x 5 = 325MHz
                (RESOLUTION=="SXGA") ?                  2.0 :              // 108MHz x 5 = 540MHz(540.625/5=108.125MHz)
                (RESOLUTION=="HD") ?                    1.0 : 1.0;         // 148.5MHz x 5 = 742.5MHz(743.75/5=148.75MHz)
