#include "hls_video.h"
#include <iostream>
#include <string.h>
#include <hls_stream.h>
#include <ap_axi_sdata.h>
#include <stdio.h>
#include "consts.h"
//#include "learned_data.h"

#define IMAGE_WIDTH       800
#define IMAGE_HEIGHT      600
#define WINDOW_WIDTH      64
#define WINDOW_HEIGHT     128
#define WINDOW_BLOCKNUM_W 7
#define WINDOW_BLOCKNUM_H 15
#define BLOCK_NUM_W       (IMAGE_WIDTH  / CELL_SIZE -1) //99
#define BLOCK_NUM_H       (IMAGE_HEIGHT / CELL_SIZE -1) //75
#define WINDOW_NUM_W      (IMAGE_WIDTH  / CELL_SIZE - WINDOW_BLOCKNUM_W) //93
#define WINDOW_NUM_H      (IMAGE_HEIGHT / CELL_SIZE - WINDOW_BLOCKNUM_H) //60
#define PI                3.14159265359

//HOG Parameters
#define CELL_SIZE    8
#define BLOCK_SIZE   2
#define HIST_BIN_NUM 9

typedef int magnitude_fixed;


inline int approx_distance(int dx, int dy){
	int min, max; //uint
	if(dx < 0) dx = -dx;
	if(dy < 0) dy = -dy;
	return (sqrt(dx^2+dy^2));
/*
	if(dx < dy){
		min = dx;
		max = dy;
	}else{
		min = dy;
		max = dx;
	}

	//coefficients equivalent to (123/128 * max) and (51/128*min)
	return ((( max << 8 ) + ( max << 3 ) - ( max << 4 ) - ( max << 1 ) +
	            ( min << 7 ) - ( min << 5 ) + ( min << 3 ) - ( min << 1 )) >> 8 );
*/}

void compute_mag_and_bin(hls::stream<ap_axis<8,1,1,1> >& instream, hls::stream<ap_axis<32,1,1,1> >& magstream, hls::stream<ap_axis<32,1,1,1> >& binstream){
	ap_axis<8,1,1,1> in;
	//Lookup tables for tan(20)*Gx
	int tan20x[256] = {0,0,0,1,1,1,2,2,2,3,3,3,4,4,5,5,5,6,6,6,7,7,7,8,8,9,9,9,10,10,10,11,11,11,12,12,13,13,13,14,14,14,15,15,15,16,16,17,17,17,18,18,18,19,19,19,20,20,21,21,21,22,22,22,23,23,23,24,24,25,25,25,26,26,26,27,27,27,28,28,29,29,29,30,30,30,31,31,31,32,32,33,33,33,34,34,34,35,35,35,36,36,37,37,37,38,38,38,39,39,39,40,40,41,41,41,42,42,42,43,43,43,44,44,45,45,45,46,46,46,47,47,47,48,48,49,49,49,50,50,50,51,51,51,52,52,53,53,53,54,54,54,55,55,55,56,56,57,57,57,58,58,58,59,59,59,60,60,61,61,61,62,62,62,63,63,63,64,64,65,65,65,66,66,66,67,67,67,68,68,69,69,69,70,70,70,71,71,71,72,72,73,73,73,74,74,74,75,75,75,76,76,77,77,77,78,78,78,79,79,79,80,80,81,81,81,82,82,82,83,83,83,84,84,85,85,85,86,86,86,87,87,87,88,88,89,89,89,90,90,90,91,91,91,92,92};
#pragma HLS RESOURCE variable=tan20x core=ROM_1P_BRAM
	//Lookup tables for tan(40)*Gx
	int tan40x[256] = {0,0,1,2,3,4,5,5,6,7,8,9,10,10,11,12,13,14,15,15,16,17,18,19,20,20,21,22,23,24,25,26,26,27,28,29,30,31,31,32,33,34,35,36,36,37,38,39,40,41,41,42,43,44,45,46,46,47,48,49,50,51,52,52,53,54,55,56,57,57,58,59,60,61,62,62,63,64,65,66,67,67,68,69,70,71,72,72,73,74,75,76,77,78,78,79,80,81,82,83,83,84,85,86,87,88,88,89,90,91,92,93,93,94,95,96,97,98,98,99,100,101,102,103,104,104,105,106,107,108,109,109,110,111,112,113,114,114,115,116,117,118,119,119,120,121,122,123,124,124,125,126,127,128,129,130,130,131,132,133,134,135,135,136,137,138,139,140,140,141,142,143,144,145,145,146,147,148,149,150,150,151,152,153,154,155,156,156,157,158,159,160,161,161,162,163,164,165,166,166,167,168,169,170,171,171,172,173,174,175,176,177,177,178,179,180,181,182,182,183,184,185,186,187,187,188,189,190,191,192,192,193,194,195,196,197,197,198,199,200,201,202,203,203,204,205,206,207,208,208,209,210,211,212,213,213};
#pragma HLS RESOURCE variable=tan40x core=ROM_1P_BRAM
	//Lookup tables for tan(60)*Gx
	int tan60x[256] = {0,1,3,5,6,8,10,12,13,15,17,19,20,22,24,25,27,29,31,32,34,36,38,39,41,43,44,46,48,50,51,53,55,57,58,60,62,63,65,67,69,70,72,74,76,77,79,81,83,84,86,88,89,91,93,95,96,98,100,102,103,105,107,108,110,112,114,115,117,119,121,122,124,126,127,129,131,133,134,136,138,140,141,143,145,147,148,150,152,153,155,157,159,160,162,164,166,167,169,171,172,174,176,178,179,181,183,185,186,188,190,191,193,195,197,198,200,202,204,205,207,209,210,212,214,216,217,219,221,223,224,226,228,230,231,233,235,236,238,240,242,243,245,247,249,250,252,254,255,257,259,261,262,264,266,268,269,271,273,274,276,278,280,281,283,285,287,288,290,292,294,295,297,299,300,302,304,306,307,309,311,313,314,316,318,319,321,323,325,326,328,330,332,333,335,337,338,340,342,344,345,347,349,351,352,354,356,358,359,361,363,364,366,368,370,371,373,375,377,378,380,382,383,385,387,389,390,392,394,396,397,399,401,402,404,406,408,409,411,413,415,416,418,420,421,423,425,427,428,430,432,434,435,437,439,441};
#pragma HLS RESOURCE variable=tan60x core=ROM_1P_BRAM
	//Lookup tables for tan(80)*Gx
	int tan80x[256] = {0,5,11,17,22,28,34,39,45,51,56,62,68,73,79,85,90,96,102,107,113,119,124,130,136,141,147,153,158,164,170,175,181,187,192,198,204,209,215,221,226,232,238,243,249,255,260,266,272,277,283,289,294,300,306,311,317,323,328,334,340,345,351,357,362,368,374,379,385,391,396,402,408,413,419,425,430,436,442,447,453,459,464,470,476,481,487,493,498,504,510,515,521,527,532,538,544,549,555,561,566,572,578,584,589,595,601,606,612,618,623,629,635,640,646,652,657,663,669,674,680,686,691,697,703,708,714,720,725,731,737,742,748,754,759,765,771,776,782,788,793,799,805,810,816,822,827,833,839,844,850,856,861,867,873,878,884,890,895,901,907,912,918,924,929,935,941,946,952,958,963,969,975,980,986,992,997,1003,1009,1014,1020,1026,1031,1037,1043,1048,1054,1060,1065,1071,1077,1082,1088,1094,1099,1105,1111,1116,1122,1128,1133,1139,1145,1150,1156,1162,1168,1173,1179,1185,1190,1196,1202,1207,1213,1219,1224,1230,1236,1241,1247,1253,1258,1264,1270,1275,1281,1287,1292,1298,1304,1309,1315,1321,1326,1332,1338,1343,1349,1355,1360,1366,1372,1377,1383,1389,1394,1400,1406,1411,1417,1423,1428,1434,1440,1445};
#pragma HLS RESOURCE variable=tan80x core=ROM_1P_BRAM

	hls::LineBuffer<2, IMAGE_WIDTH, unsigned char> linebuf;
	hls::Window<3, 3, unsigned char> winbuf;

	//calculate magnitude using shift register
	loop_y:for(int y = 0; y < IMAGE_HEIGHT; y++){
	loop_x:for(int x = 0; x < IMAGE_WIDTH; x++){
#pragma HLS PIPELINE II=1


 ////////参�??�?よりも若干ロジ�?ク数減らせる//////////
			bool isedge = (x < 2 || y < 2);
			instream >> in;

			linebuf.shift_pixels_up(x);
			linebuf.insert_bottom_row(in.data, x);

			winbuf.shift_pixels_right();
			//these operation will be executed in parallel.
			winbuf.insert_pixel(linebuf.getval(0, x), 0, 0);
			winbuf.insert_pixel(linebuf.getval(1, x), 1, 0);
			winbuf.insert_pixel(in.data, 2, 0);

			int Gx = isedge ? 0 : (int)winbuf.getval(1, 0) - (int)winbuf.getval(1, 2);
			int Gy = isedge ? 0 : (int)winbuf.getval(2, 1) - (int)winbuf.getval(0, 1);


			int Gx_r = abs(Gx); //absolute value of Gx(i,j)
			int Gy_r = abs(Gy); //absolute value of Gy(i,j)


		    int bin_index;
/*
		    float bin_index;
            bin_index = atan2((double)Gy, (double)Gx);
            bin_index = (bin_index*180.0)/PI;

            if(bin_index < 0.0){
                bin_index += 360.0;
            }
            if(bin_index > 180.0){
            	bin_index -= 180.0;
            }

			bin_index = bin_index/20;
*/


			int GxGy_xor = ((Gx >= 0 && Gy >= 0) || (Gx <= 0 && Gy <= 0)) ? 0 : 1;

			if (GxGy_xor == 0){
   				  if (Gy_r <= tan20x[Gx_r]) bin_index = 0;
			 else if (Gy_r <  tan40x[Gx_r]) bin_index = 1;
			 else if (Gy_r <  tan60x[Gx_r]) bin_index = 2;
			 else if (Gy_r <  tan80x[Gx_r]) bin_index = 3;
			 else                           bin_index = 4;
			}else{
				  if (Gy_r <= tan20x[Gx_r]) bin_index = 8;
			 else if (Gy_r <  tan40x[Gx_r]) bin_index = 7;
     	  	 else if (Gy_r <  tan60x[Gx_r]) bin_index = 6;
			 else if (Gy_r <  tan80x[Gx_r]) bin_index = 5;
			 else                           bin_index = 4;
			}

			int mag = isedge ? 0 : approx_distance(Gx, Gy);

			ap_axis<32,1,1,1> m,b;
			m.data = mag;
			b.data = bin_index;
			magstream << m;
			binstream << b;
		}
	}
}

typedef int blockpart_fixed;
typedef int blocksum_fixed;


struct ap_fixed_point9{
	ap_fixed_point data[HIST_BIN_NUM];
};

struct blockpart_fixed_9{
	blockpart_fixed data[HIST_BIN_NUM];
};


typedef hls::stream<ap_axis<32,1,1,1> > block_out;
void cell_histogram_generate(hls::stream<ap_axis<32,1,1,1> >& magstream, hls::stream<ap_axis<32,1,1,1> >& binstream,
		hls::stream<blockpart_fixed_9>& bottom, hls::stream<blockpart_fixed_9>& upper){

	hls::LineBuffer<2, IMAGE_WIDTH/CELL_SIZE*9, int> cellbuf;
	hls::LineBuffer<CELL_SIZE, IMAGE_WIDTH/CELL_SIZE*9, int> linebufs;

#pragma HLS ARRAY_PARTITION variable=linebufs block factor =9 dim=2 //100個単位�?�配�?�にする
#pragma HLS ARRAY PARTITION variable=cellbuf block factor =9 dim=2

	int vote_counter[HIST_BIN_NUM] = {0};
#pragma HLS ARRAY_PARTITION variable=vote_counter complete dim=1
	loop_y:for(int y = 0; y < IMAGE_HEIGHT; y++){
		loop_winx:for(int cell_num = 0; cell_num < IMAGE_WIDTH / CELL_SIZE; cell_num++){
			loop_cell_index:for(int cell_index = 0; cell_index < CELL_SIZE; cell_index++){
#pragma HLS PIPELINE II=1
				ap_axis<32,1,1,1> mag, bin;
				magstream >> mag;
				binstream >> bin;
				vote_counter[(int)bin.data] += mag.data;
				if(cell_index == CELL_SIZE-1){
					loop_updatelinebuf:for(int i = 0; i < HIST_BIN_NUM; i++){
						linebufs.shift_pixels_up(cell_num + i * IMAGE_WIDTH/CELL_SIZE);
						linebufs.insert_bottom_row(vote_counter[i],cell_num + i * IMAGE_WIDTH/CELL_SIZE);
					}
					int sum_of_cell[9];
					if(y%8 == 7){
						blockpart_fixed_9 out_upper, out_bottom;
						loop_cellbuf_calc:for(int bin_index = 0; bin_index < HIST_BIN_NUM; bin_index++){

							sum_of_cell[bin_index] = linebufs.getval(0,cell_num+ bin_index * IMAGE_WIDTH/CELL_SIZE)+ linebufs.getval(1,cell_num+ bin_index * IMAGE_WIDTH/CELL_SIZE)+linebufs.getval(2,cell_num+ bin_index * IMAGE_WIDTH/CELL_SIZE)+linebufs.getval(3,cell_num+ bin_index * IMAGE_WIDTH/CELL_SIZE)+linebufs.getval(4,cell_num+ bin_index * IMAGE_WIDTH/CELL_SIZE)+linebufs.getval(5,cell_num+ bin_index * IMAGE_WIDTH/CELL_SIZE)+linebufs.getval(6,cell_num+ bin_index * IMAGE_WIDTH/CELL_SIZE)+linebufs.getval(7,cell_num+ bin_index * IMAGE_WIDTH/CELL_SIZE);
#pragma HLS ARRAY_PARTITION variable=sum_of_cell block factor=9

							cellbuf.shift_pixels_up  (cell_num+ bin_index * IMAGE_WIDTH/CELL_SIZE);
							cellbuf.insert_bottom_row( sum_of_cell[bin_index],cell_num+ bin_index * IMAGE_WIDTH/CELL_SIZE);


							if(y >= CELL_SIZE * BLOCK_SIZE - 1){ //y >= 15
								out_upper.data[bin_index]  = cellbuf.getval(0,cell_num+ bin_index * IMAGE_WIDTH/CELL_SIZE);
								out_bottom.data[bin_index] = cellbuf.getval(1,cell_num+ bin_index * IMAGE_WIDTH/CELL_SIZE);
								if(bin_index == 8){
											bottom << out_bottom;
											upper << out_upper;
								}
							}
						}
					}
				//zeroing
				for(int i = 0; i < HIST_BIN_NUM; i++) vote_counter[i] = 0;
				}
			}
		}
	}
}

ap_fixed_point div_int_to_ap_fixed(blockpart_fixed a, blocksum_fixed b){
	if(a == 0 || b == 0) return (ap_fixed_point)0;
	ap_uint<64> aa = a;
	ap_uint<64> bb = b;
	ap_uint<64> target_a = aa << 32;
	ap_uint<64> target_b = bb << 16;
	ap_uint<64> c = target_a / target_b;

	ap_fixed_point ans = 0;
	ans.range(22,6) = c.range(16,0);
	return ans;
}


void block_histogram_normalization(hls::stream<blockpart_fixed_9>& bottom, hls::stream<blockpart_fixed_9>& upper,
		hls::stream<ap_fixed_point9>& ul_out, hls::stream<ap_fixed_point9>& ur_out, hls::stream<ap_fixed_point9>& bl_out, hls::stream<ap_fixed_point9>& br_out){
	hls::LineBuffer<2, 1, blockpart_fixed> bottomfifo[HIST_BIN_NUM], upperfifo[HIST_BIN_NUM]; //<row,col,type>
	blocksum_fixed  partial_old_block_sum = 0;
#pragma HLS ARRAY_PARTITION variable=bottomfifo complete dim=1
#pragma HLS ARRAY PARTITION variable=upperfifo complete dim=1
	for(int y = 0; y < (IMAGE_HEIGHT / CELL_SIZE - BLOCK_SIZE + 1); y++){ //59
		for(int x = 0; x < (IMAGE_WIDTH / CELL_SIZE); x++){               //80
			blockpart_fixed_9 bottom_in = bottom.read();
			blockpart_fixed_9 upper_in = upper.read();
			ap_fixed_point9 ul, ur, bl, br;

			blocksum_fixed partial_block_new_sum = 0;

			for(int bin_index = 0; bin_index < HIST_BIN_NUM; bin_index++){
#pragma HLS PIPELINE II=1
				blockpart_fixed b = bottom_in.data[bin_index];
				blockpart_fixed u = upper_in.data[bin_index];
				bottomfifo[bin_index].shift_pixels_up(0);
				bottomfifo[bin_index].insert_bottom_row(b, 0);
				upperfifo[bin_index].shift_pixels_up(0);
				upperfifo[bin_index].insert_bottom_row(u, 0);

				partial_block_new_sum += (b + u);
			}
			bool sum_of_block_completed = (x >= 1);
			if(sum_of_block_completed){
				blocksum_fixed block_sum = partial_block_new_sum + partial_old_block_sum;
				for(int bin_index = 0; bin_index < HIST_BIN_NUM; bin_index++){
	#pragma HLS PIPELINE II=1
					//59*79
					//normalization
					blockpart_fixed un_upperleft   = upperfifo [bin_index].getval(0, 0);
					blockpart_fixed un_upperright  = upperfifo [bin_index].getval(1, 0);
					blockpart_fixed un_bottomleft  = bottomfifo[bin_index].getval(0, 0);
					blockpart_fixed un_bottomright = bottomfifo[bin_index].getval(1, 0);
#pragma HLS allocation instances=div_int_to_ap_fixed limit=1 function

					ap_fixed_point upperleft   = div_int_to_ap_fixed(un_upperleft, block_sum);
					ap_fixed_point upperright  = div_int_to_ap_fixed(un_upperright, block_sum);
					ap_fixed_point bottomleft  = div_int_to_ap_fixed(un_bottomleft, block_sum);
					ap_fixed_point bottomright = div_int_to_ap_fixed(un_bottomright, block_sum);

					ul.data[bin_index] = upperleft;
					ur.data[bin_index] = upperright;
					bl.data[bin_index] = bottomleft;
					br.data[bin_index] = bottomright;
				}
				ul_out << ul;
				ur_out << ur;
				bl_out << bl;
				br_out << br;
			}
			partial_old_block_sum = partial_block_new_sum;
		}
	}
}


accum_fixed multiply_accum_hog(ap_fixed<128,106> weight, ap_fixed_point ul, ap_fixed_point ur, ap_fixed_point bl, ap_fixed_point br){
	ap_fixed_point ul_weight = 0;
	ap_fixed_point ur_weight = 0;
	ap_fixed_point bl_weight = 0;
	ap_fixed_point br_weight = 0;

	br_weight.range(31, 0) = weight.range(127, 96); //br
	bl_weight.range(31, 0) = weight.range(95, 64); //bl
	ur_weight.range(31, 0) = weight.range(63, 32); //ur
	ul_weight.range(31, 0) = weight.range(31, 0); //ul

	//#pragma HLS allocation instances=mul limit=2
	//ap_fixed_point hoge = ul_weight;
	//return ul_weight;
    //return (accum_fixed)ul_weight * (accum_fixed)ul + (accum_fixed)ur_weight * (accum_fixed)ur + (accum_fixed)bl_weight * (accum_fixed)bl + (accum_fixed)br_weight * (accum_fixed)br;
    accum_fixed hoge = ul_weight * ul + ur_weight * ur + bl_weight * bl + br_weight * br;
	return hoge;
}
void hog_svm_classification(hls::stream<ap_fixed_point9>& upperleft, hls::stream<ap_fixed_point9>& upperright, hls::stream<ap_fixed_point9>& bottomleft, hls::stream<ap_fixed_point9>& bottomright,
		hls::stream<accum_fixed>& resultstream, hogweight w1[7], hogweight w2[7], hogweight w3[7],hogweight w4[7],hogweight w5[7],hogweight w6[7],hogweight w7[7],hogweight w8[7],hogweight w9[7],
		hogweight w10[7],hogweight w11[7],hogweight w12[7],hogweight w13[7],hogweight w14[7],hogweight w15[7]){
	accum_fixed PartialSum[WINDOW_BLOCKNUM_H][WINDOW_NUM_W];
//#pragma HLS ARRAY_PARTITION variable=PartialSum complete dim=1
#pragma HLS ARRAY_PARTITION variable=PartialSum block factor =15 dim=1
#pragma HLS RESOURCE variable=PartialSum core=RAM_2P_BRAM

	for(int i = 0; i < WINDOW_BLOCKNUM_H; i++){
		for(int j = 0; j < WINDOW_NUM_W; j++){
#pragma HLS PIPELINE II=1
			PartialSum[i][j] = 0;
		}
	}
	loop_y:for(int y = 0; y < BLOCK_NUM_H; y++){
		loop_x:for(int x = 0; x < BLOCK_NUM_W; x++){
			ap_fixed_point9 ul = upperleft.read();
			ap_fixed_point9 ur = upperright.read();
			ap_fixed_point9 bl = bottomleft.read();
			ap_fixed_point9 br = bottomright.read();
//#pragma HLS PIPELINE II=1
			for(int block_index_x = 6; block_index_x >= 0; block_index_x--){
#pragma HLS PIPELINE II=1
				bool inside_window = (block_index_x <= x && x <= block_index_x + (IMAGE_WIDTH / 8 - 8));
				if(inside_window){
					int winx = x - block_index_x;
					//block_index_y indicates where (ul,ur,bl,br) is located in the window in y axis.
					loop_block_index_y:for(int block_index_y = 0; block_index_y < WINDOW_BLOCKNUM_H; block_index_y++){
						int block_start_y = y - block_index_y;
						if(0 <= block_start_y && block_start_y <= (BLOCK_NUM_H - WINDOW_BLOCKNUM_H)){
							int partial_sum_index_y = (y - block_index_y) % WINDOW_BLOCKNUM_H;
							hogweight w;// = WeightData[block_index_y][block_index_x];
							if(block_index_y == 0) w = w1[block_index_x];
							else if(block_index_y == 1) w = w2[block_index_x];
							else if(block_index_y == 2) w = w3[block_index_x];
							else if(block_index_y == 3) w = w4[block_index_x];
							else if(block_index_y == 4) w = w5[block_index_x];
							else if(block_index_y == 5) w = w6[block_index_x];
							else if(block_index_y == 6) w = w7[block_index_x];
							else if(block_index_y == 7) w = w8[block_index_x];
							else if(block_index_y == 8) w = w9[block_index_x];
							else if(block_index_y == 9) w = w10[block_index_x];
							else if(block_index_y == 10) w = w11[block_index_x];
							else if(block_index_y == 11) w = w12[block_index_x];
							else if(block_index_y == 12) w = w13[block_index_x];
							else if(block_index_y == 13) w = w14[block_index_x];
							else w = w15[block_index_x];

							accum_fixed tmp_partial_sum = 0;
							for(int i = 0; i < 9; i++) tmp_partial_sum += multiply_accum_hog(w.weightval[i], ul.data[i], ur.data[i], bl.data[i], br.data[i]);
							//ap_fixed<32,10> fuga;
							//w=w15[0];
							//fuga.range(31,0)= w.weightval[0].range(127,96);
							//fuga = multiply_accum_hog(w.weightval[0], ul.data[0], ur.data[0], bl.data[0], br.data[0]);
							if(block_index_y == 0 && block_index_x == 0) PartialSum[partial_sum_index_y][winx] = tmp_partial_sum;
							else PartialSum[partial_sum_index_y][winx] += tmp_partial_sum;

							bool window_completed = (block_index_x == (WINDOW_BLOCKNUM_W - 1) && block_index_y == (WINDOW_BLOCKNUM_H - 1));
							if(window_completed){
								accum_fixed allsum = PartialSum[partial_sum_index_y][winx];
								//PartialSum[partial_sum_index_y][winx] = 0;
								//ap_axis<8,1,1,1> ap_y, ap_x;
								//ap_y.data = block_start_y;
								//ap_x.data = winx;
								resultstream.write(allsum);
							}
						}
					}
				}
			}
		}
	}

}



void hog_svm(hls::stream<ap_axis<8,1,1,1> >& instream,hls::stream<accum_fixed >& outstream, hogweight hog_w1[7],hogweight hog_w2[7],hogweight hog_w3[7],hogweight hog_w4[7],
		     hogweight hog_w5[7],hogweight hog_w6[7],hogweight hog_w7[7],hogweight hog_w8[7],hogweight hog_w9[7],hogweight hog_w10[7],hogweight hog_w11[7],hogweight hog_w12[7],
			 hogweight hog_w13[7],hogweight hog_w14[7],hogweight hog_w15[7]){

	hls::stream<ap_uint<8> > gray_pix;
	//hls::stream<magnitude_fixed > magstream;
	//hls::stream<int> binstream;
	hls::stream<blockpart_fixed_9 > bottom, upper;
	hls::stream<ap_fixed_point9 > ul_out, ur_out, bl_out, br_out;
	hls::stream<accum_fixed> hog_resultstream;
	hls::stream<ap_axis<32,1,1,1> > magstream;
	hls::stream<ap_axis<32,1,1,1> > binstream;

#pragma HLS STREAM variable = bottom depth = 5 dim = 9
#pragma HLS STREAM variable = upper depth = 5 dim = 9
#pragma HLS STREAM variable = ul_out depth= 5 dim = 9
#pragma HLS STREAM variable = ur_out depth= 5 dim = 9
#pragma HLS STREAM variable = bl_out depth= 5 dim = 9
#pragma HLS STREAM variable = br_out depth= 5 dim = 9
#pragma HLS STREAM variable = magstream depth = 5 dim =9
#pragma HLS STREAM variable = binstream depth = 5 dim =9
#pragma HLS STREAM variable = hog_resultstream depth = 5 dim =9


#pragma HLS INTERFACE axis port=instream
#pragma HLS INTERFACE axis port=outstream

#pragma HLS INTERFACE bram port=hog_w1
#pragma HLS INTERFACE bram port=hog_w2
#pragma HLS INTERFACE bram port=hog_w3
#pragma HLS INTERFACE bram port=hog_w4
#pragma HLS INTERFACE bram port=hog_w5
#pragma HLS INTERFACE bram port=hog_w6
#pragma HLS INTERFACE bram port=hog_w7
#pragma HLS INTERFACE bram port=hog_w8
#pragma HLS INTERFACE bram port=hog_w9
#pragma HLS INTERFACE bram port=hog_w10
#pragma HLS INTERFACE bram port=hog_w11
#pragma HLS INTERFACE bram port=hog_w12
#pragma HLS INTERFACE bram port=hog_w13
#pragma HLS INTERFACE bram port=hog_w14
#pragma HLS INTERFACE bram port=hog_w15

#pragma HLS RESOURCE variable = hog_w1 core=RAM_1P_BRAM
#pragma HLS RESOURCE variable = hog_w2 core=RAM_1P_BRAM
#pragma HLS RESOURCE variable = hog_w3 core=RAM_1P_BRAM
#pragma HLS RESOURCE variable = hog_w4 core=RAM_1P_BRAM
#pragma HLS RESOURCE variable = hog_w5 core=RAM_1P_BRAM
#pragma HLS RESOURCE variable = hog_w6 core=RAM_1P_BRAM
#pragma HLS RESOURCE variable = hog_w7 core=RAM_1P_BRAM
#pragma HLS RESOURCE variable = hog_w8 core=RAM_1P_BRAM
#pragma HLS RESOURCE variable = hog_w9 core=RAM_1P_BRAM
#pragma HLS RESOURCE variable = hog_w10 core=RAM_1P_BRAM
#pragma HLS RESOURCE variable = hog_w11 core=RAM_1P_BRAM
#pragma HLS RESOURCE variable = hog_w12 core=RAM_1P_BRAM
#pragma HLS RESOURCE variable = hog_w13 core=RAM_1P_BRAM
#pragma HLS RESOURCE variable = hog_w14 core=RAM_1P_BRAM
#pragma HLS RESOURCE variable = hog_w15 core=RAM_1P_BRAM
#pragma HLS INTERFACE s_axilite port=return bundle = CONTROL_BUS
#pragma DATAFLOW


    compute_mag_and_bin(instream, magstream, binstream);
	cell_histogram_generate(magstream, binstream, bottom,upper);
	block_histogram_normalization(bottom, upper,ul_out, ur_out, bl_out,br_out);
	hog_svm_classification(ul_out,ur_out,bl_out,br_out,hog_resultstream,hog_w1,hog_w2,hog_w3,hog_w4,hog_w5,hog_w6,hog_w7,hog_w8,hog_w9,hog_w10,hog_w11,hog_w12,hog_w13,hog_w14,hog_w15);
	int outputnum = WINDOW_NUM_H * WINDOW_NUM_W;

	//conversion between the 32-bit floating point data of the matrices and the 32-bit unsigned data of AXI.
	for(int i = 0; i < outputnum; i++){
		accum_fixed hog = hog_resultstream.read();
		//ap_fixed<32,10> hoge;
		//hoge.range(31,0)=hog_w1[0].weightval[0].range(127,96);
	/*	float final_rst_float = bined.to_float();
		ap_axiu<32,1,1,1>  val;
		union{
			int oval;
			float ival;
		} converter;
		converter.ival = final_rst_float;
		val.data = converter.oval;
		val.last = (i == outputnum-1) ? 1 : 0;
		val.strb = -1;
		val.keep = 15;
		val.user = 0;
		val.id = 0;
		val.dest = 0;*/
		outstream.write(hog);
	}


	//normalizeBlock(sum_of_block, descriptor, normalized);
	//memcpy(feature, normalized, HISTOGRAMSIZE * sizeof(unsigned short));
}
