// video_timing_param.vh
// by marsee
// 2014/07/26

parameter integer H_ACTIVE_VIDEO = (RESOLUTION=="VGA") ?    640 :   // VGA    25MHz
                    (RESOLUTION=="SVGA") ?                  800 :   // SVGA   40MHz
                    (RESOLUTION=="XGA") ?                   1024 :  // XGA    65MHz
                    (RESOLUTION=="SXGA") ?                  1280 :  // SXGA   108MHz
                    (RESOLUTION=="HD") ?                    1920 : 1920;    // HD     148.5MHz

parameter integer H_FRONT_PORCH = (RESOLUTION=="VGA") ? 16 :    // VGA
                    (RESOLUTION=="SVGA") ?              40 :    // SVGA
                    (RESOLUTION=="XGA") ?               24 :    // XGA
                    (RESOLUTION=="SXGA") ?              48 :    // SXGA
                    (RESOLUTION=="HD") ?                88 : 88;    // HD

parameter integer H_SYNC_PULSE = (RESOLUTION=="VGA") ?  96 :    // VGA
                    (RESOLUTION=="SVGA") ?              128 :   // SVGA
                    (RESOLUTION=="XGA") ?               136 :   // XGA
                    (RESOLUTION=="SXGA") ?              112 :   // SXGA
                    (RESOLUTION=="HD") ?                44 : 44;    // HD

parameter integer H_BACK_PORCH = (RESOLUTION=="VGA") ?  48 :    // VGA
                    (RESOLUTION=="SVGA") ?              88 :    // SVGA
                    (RESOLUTION=="XGA") ?               160 :   // XGA
                    (RESOLUTION=="SXGA") ?              248 :   // SXGA
                    (RESOLUTION=="HD") ?                148 : 148;  // HD

parameter integer V_ACTIVE_VIDEO = (RESOLUTION=="VGA") ?    480 :   // VGA
                    (RESOLUTION=="SVGA") ?                  600 :   // SVGA
                    (RESOLUTION=="XGA") ?                   768 :   // XGA
                    (RESOLUTION=="SXGA") ?                  1024 :  // SXGA
                    (RESOLUTION=="HD") ?                    1080 : 1080;    // HD

parameter integer V_FRONT_PORCH = (RESOLUTION=="VGA") ? 11 :    // VGA
                    (RESOLUTION=="SVGA") ?              1 : // SVGA
                    (RESOLUTION=="XGA") ?               2 : // XGA
                    (RESOLUTION=="SXGA") ?              1 : // SXGA
                    (RESOLUTION=="HD") ?                4 : 4;  // HD

parameter integer V_SYNC_PULSE = (RESOLUTION=="VGA") ? 2 :  // VGA
                    (RESOLUTION=="SVGA") ?              4 : // SVGA
                    (RESOLUTION=="XGA") ?               6 : // XGA
                    (RESOLUTION=="SXGA") ?              3 : // SXGA
                    (RESOLUTION=="HD") ?                5 : 5;  // HD

parameter integer V_BACK_PORCH = (RESOLUTION=="VGA") ?  31 :    // VGA
                    (RESOLUTION=="SVGA") ?              23 :    // SVGA
                    (RESOLUTION=="XGA") ?               29 :    // XGA
                    (RESOLUTION=="SXGA") ?              38 :    // SXGA
                    (RESOLUTION=="HD") ?                36 : 36;    // HD

    parameter H_SUM = H_ACTIVE_VIDEO + H_FRONT_PORCH + H_SYNC_PULSE + H_BACK_PORCH;
    parameter V_SUM = V_ACTIVE_VIDEO + V_FRONT_PORCH + V_SYNC_PULSE + V_BACK_PORCH;

    parameter H_DISPLAY_SIZE = H_ACTIVE_VIDEO/8; // 横?桁
    parameter V_DISPLAY_SIZE = V_ACTIVE_VIDEO/8; // 縦?行
    parameter ALL_CHAR_SIZE = H_DISPLAY_SIZE*V_DISPLAY_SIZE;

    parameter RED_DOT_POS = 15; // 15～13ビット目がRED
    parameter GREEN_DOT_POS = 12; // 12～10ビット目がGREEN
    parameter BLUE_DOT_POS = 9; // 9～7ビット目がBLUE
    parameter COLOR_ATTRIB_WIDHT = 3;   // 色情報のビット幅
