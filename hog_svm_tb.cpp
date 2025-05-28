//#include "/opt/Xilinx/Vivado/2018.2/include/gmp.h"
#include <iostream>
#include <cmath>
#include <string.h>
#include <vector>
#include <ap_fixed.h>
#include <ap_axi_sdata.h>
//#include "weight.h"
#include <opencv2/opencv.hpp>
#include <hls_stream.h>
#include <sstream>
#include "consts.h"
#include "learned_data.h"

using namespace std;
using namespace cv;

void hog_svm(hls::stream<ap_axis<8,1,1,1> >& instream, hls::stream<accum_fixed >& outstream,
		hogweight hog_w1[7], hogweight hog_w2[7], hogweight hog_w3[7], hogweight hog_w4[7], hogweight hog_w5[7], hogweight hog_w6[7], hogweight hog_w7[7], hogweight hog_w8[7], hogweight hog_w9[7], hogweight hog_w10[7], hogweight hog_w11[7], hogweight hog_w12[7], hogweight hog_w13[7], hogweight hog_w14[7], hogweight hog_w15[7]);

string tostr(double val){
	std::stringstream ss;
	ss << val;
	std::string str = ss.str();
	return str;
}

hogweight bound_hog_w1[7], bound_hog_w2[7], bound_hog_w3[7], bound_hog_w4[7], bound_hog_w5[7], bound_hog_w6[7], bound_hog_w7[7], bound_hog_w8[7], bound_hog_w9[7], bound_hog_w10[7], bound_hog_w11[7], bound_hog_w12[7], bound_hog_w13[7], bound_hog_w14[7], bound_hog_w15[7];

void prepare_bound_input(){

	for(int i = 0; i < 7; i++){       //block_num
		for(int j = 0; j < 9; j++){   //bin
			int index = (i*36+j);
			ap_fixed<128,106> tmp = 0;
			tmp.range(31 , 0) = unbound_hog_w1[index]  .range(31,0);//ul
			tmp.range(63 , 32) = unbound_hog_w1[index+9].range(31,0);//ur
			tmp.range(95 ,64) = unbound_hog_w1[index+18].range(31,0);//bl
			tmp.range(127 ,96) = unbound_hog_w1[index+27].range(31,0);//br
			bound_hog_w1[i].weightval[j] = tmp;
			/*test display
			ap_fixed<24,2> hoge;
			hoge.range(31,0) = bound_hog_w1[0].weightval[0].range(31,0);
			//hoge.range(31,0) = tmp  .range(127 ,96);
			cout << hoge << endl;*/
		}
	}
	for(int i = 0; i < 7; i++){
		for(int j = 0; j < 9; j++){
			int index = (i*36+j);
			ap_fixed<128,106> tmp = 0;
			tmp.range(31 , 0) = unbound_hog_w2[index]  .range(31,0);//ul
			tmp.range(63 , 32) = unbound_hog_w2[index+9].range(31,0);//ur
			tmp.range(95 ,64) = unbound_hog_w2[index+18].range(31,0);//bl
			tmp.range(127 ,96) = unbound_hog_w2[index+27].range(31,0);//br
			bound_hog_w2[i].weightval[j] = tmp;
		}
	}
	for(int i = 0; i < 7; i++){
		for(int j = 0; j < 9; j++){
			int index = (i*36+j);
			ap_fixed<128,106> tmp = 0;
			tmp.range(31 , 0) = unbound_hog_w3[index]  .range(31,0);//ul
			tmp.range(63 , 32) = unbound_hog_w3[index+9].range(31,0);//ur
			tmp.range(95 ,64) = unbound_hog_w3[index+18].range(31,0);//bl
			tmp.range(127 ,96) = unbound_hog_w3[index+27].range(31,0);//br
			bound_hog_w3[i].weightval[j] = tmp;
		}
	}
	for(int i = 0; i < 7; i++){
		for(int j = 0; j < 9; j++){
			int index = (i*36+j);
			ap_fixed<128,106> tmp = 0;
			tmp.range(31 , 0) = unbound_hog_w4[index]  .range(31,0);//ul
			tmp.range(63 , 32) = unbound_hog_w4[index+9].range(31,0);//ur
			tmp.range(95 ,64) = unbound_hog_w4[index+18].range(31,0);//bl
			tmp.range(127 ,96) = unbound_hog_w4[index+27].range(31,0);//br
			bound_hog_w4[i].weightval[j] = tmp;
		}
	}
	for(int i = 0; i < 7; i++){
		for(int j = 0; j < 9; j++){
			int index = (i*36+j);
			ap_fixed<128,106> tmp = 0;
			tmp.range(31 , 0) = unbound_hog_w5[index]  .range(31,0);//ul
			tmp.range(63 , 32) = unbound_hog_w5[index+9].range(31,0);//ur
			tmp.range(95 ,64) = unbound_hog_w5[index+18].range(31,0);//bl
			tmp.range(127 ,96) = unbound_hog_w5[index+27].range(31,0);//br
			bound_hog_w5[i].weightval[j] = tmp;
		}
	}	for(int i = 0; i < 7; i++){
			for(int j = 0; j < 9; j++){
			int index = (i*36+j);
			ap_fixed<128,106> tmp = 0;
			tmp.range(31 , 0) = unbound_hog_w6[index]  .range(31,0);//ul
			tmp.range(63 , 32) = unbound_hog_w6[index+9].range(31,0);//ur
			tmp.range(95 ,64) = unbound_hog_w6[index+18].range(31,0);//bl
			tmp.range(127 ,96) = unbound_hog_w6[index+27].range(31,0);//br
			bound_hog_w6[i].weightval[j] = tmp;
		}
	}
	for(int i = 0; i < 7; i++){
		for(int j = 0; j < 9; j++){
			int index = (i*36+j);
			ap_fixed<128,106> tmp = 0;
			tmp.range(31 , 0) = unbound_hog_w7[index]  .range(31,0);//ul
			tmp.range(63 , 32) = unbound_hog_w7[index+9].range(31,0);//ur
			tmp.range(95 ,64) = unbound_hog_w7[index+18].range(31,0);//bl
			tmp.range(127 ,96) = unbound_hog_w7[index+27].range(31,0);//br
			bound_hog_w7[i].weightval[j] = tmp;
		}
	}	for(int i = 0; i < 7; i++){
		for(int j = 0; j < 9; j++){
			int index = (i*36+j);
			ap_fixed<128,106> tmp = 0;
			tmp.range(31 , 0) = unbound_hog_w8[index]  .range(31,0);//ul
			tmp.range(63 , 32) = unbound_hog_w8[index+9].range(31,0);//ur
			tmp.range(95 ,64) = unbound_hog_w8[index+18].range(31,0);//bl
			tmp.range(127 ,96) = unbound_hog_w8[index+27].range(31,0);//br
			bound_hog_w8[i].weightval[j] = tmp;
		}
	}
	for(int i = 0; i < 7; i++){
		for(int j = 0; j < 9; j++){
			int index = (i*36+j);
			ap_fixed<128,106> tmp = 0;
			tmp.range(31 , 0) = unbound_hog_w9[index]  .range(31,0);//ul
			tmp.range(63 , 32) = unbound_hog_w9[index+9].range(31,0);//ur
			tmp.range(95 ,64) = unbound_hog_w9[index+18].range(31,0);//bl
			tmp.range(127 ,96) = unbound_hog_w9[index+27].range(31,0);//br
			bound_hog_w9[i].weightval[j] = tmp;
		}
	}	for(int i = 0; i < 7; i++){
		for(int j = 0; j < 9; j++){
			int index = (i*36+j);
			ap_fixed<128,106> tmp = 0;
			tmp.range(31 , 0) = unbound_hog_w10[index]  .range(31,0);//ul
			tmp.range(63 , 32) = unbound_hog_w10[index+9].range(31,0);//ur
			tmp.range(95 ,64) = unbound_hog_w10[index+18].range(31,0);//bl
			tmp.range(127 ,96) = unbound_hog_w10[index+27].range(31,0);//br
			bound_hog_w10[i].weightval[j] = tmp;
		}
	}
	for(int i = 0; i < 7; i++){
		for(int j = 0; j < 9; j++){
			int index = (i*36+j);
			ap_fixed<128,106> tmp = 0;
			tmp.range(31 , 0) = unbound_hog_w11[index]  .range(31,0);//ul
			tmp.range(63 , 32) = unbound_hog_w11[index+9].range(31,0);//ur
			tmp.range(95 ,64) = unbound_hog_w11[index+18].range(31,0);//bl
			tmp.range(127 ,96) = unbound_hog_w11[index+27].range(31,0);//br
			bound_hog_w11[i].weightval[j] = tmp;
		}
	}
	for(int i = 0; i < 7; i++){
		for(int j = 0; j < 9; j++){
			int index = (i*36+j);
			ap_fixed<128,106> tmp = 0;
			tmp.range(31 , 0) = unbound_hog_w12[index]  .range(31,0);//ul
			tmp.range(63 , 32) = unbound_hog_w12[index+9].range(31,0);//ur
			tmp.range(95 ,64) = unbound_hog_w12[index+18].range(31,0);//bl
			tmp.range(127 ,96) = unbound_hog_w12[index+27].range(31,0);//br
			bound_hog_w12[i].weightval[j] = tmp;
		}
	}
	for(int i = 0; i < 7; i++){
		for(int j = 0; j < 9; j++){
			int index = (i*36+j);
			ap_fixed<128,106> tmp = 0;
			tmp.range(31 , 0) = unbound_hog_w13[index]  .range(31,0);//ul
			tmp.range(63 , 32) = unbound_hog_w13[index+9].range(31,0);//ur
			tmp.range(95 ,64) = unbound_hog_w13[index+18].range(31,0);//bl
			tmp.range(127 ,96) = unbound_hog_w13[index+27].range(31,0);//br
			bound_hog_w13[i].weightval[j] = tmp;
		}
	}
	for(int i = 0; i < 7; i++){
		for(int j = 0; j < 9; j++){
			int index = (i*36+j);
			ap_fixed<128,106> tmp = 0;
			tmp.range(31 , 0) = unbound_hog_w14[index]  .range(31,0);//ul
			tmp.range(63 , 32) = unbound_hog_w14[index+9].range(31,0);//ur
			tmp.range(95 ,64) = unbound_hog_w14[index+18].range(31,0);//bl
			tmp.range(127 ,96) = unbound_hog_w14[index+27].range(31,0);//br
			bound_hog_w14[i].weightval[j] = tmp;
		}
	}
	for(int i = 0; i < 7; i++){
		for(int j = 0; j < 9; j++){
			int index = (i*36+j);
			ap_fixed<128,106> tmp = 0;
			tmp.range(31 , 0) = unbound_hog_w15[index]  .range(31,0);//ul
			tmp.range(63 , 32) = unbound_hog_w15[index+9].range(31,0);//ur
			tmp.range(95 ,64) = unbound_hog_w15[index+18].range(31,0);//bl
			tmp.range(127 ,96) = unbound_hog_w15[index+27].range(31,0);//br
			bound_hog_w15[i].weightval[j] = tmp;
		}
	}
}
int main(){
	prepare_bound_input();

	cv::Mat img = cv::imread("test2-2.jpg");
	cv::Mat gray;
	cv::cvtColor(img, gray, CV_RGB2GRAY);
	cv::Mat frame_copy = img.clone();
	hls::stream<ap_axis<8,1,1,1> > instream;

	//Input Value Preparation
	ap_axis<8,1,1,1> in;
	for(int y = 0; y < 600; y++){
		for(int x = 0; x < 800; x++){
			in.data  = gray.ptr<uchar>(y)[x];
			instream << in;
		}
	}
	//Execute HW
	hls::stream<accum_fixed> resultstream;

	double thresh = 0.76;
	hog_svm(instream, resultstream,bound_hog_w1, bound_hog_w2, bound_hog_w3, bound_hog_w4, bound_hog_w5, bound_hog_w6, bound_hog_w7, bound_hog_w8, bound_hog_w9, bound_hog_w10, bound_hog_w11, bound_hog_w12, bound_hog_w13, bound_hog_w14, bound_hog_w15);

	int cnt = 0;
	while(!resultstream.empty()){
		int y = (cnt / 93) * 8;
		int x = (cnt % 93) * 8;
		float data = resultstream.read();
//		ap_fixed_point data;
	//	resultstream >> data;
		/*union{
			int ival;
			float oval;
		}converter;
		converter.ival = data;*/
		float rst = data ;//+ bias;//converter.oval + bias;//data;
		float proba = 1.0/(1.0 + exp(-1 * rst));
		//cout << data << endl;
		//cout << proba << endl;
		if(proba > thresh && y > 250){
			cout << fixed << setprecision(10) << rst << " " << proba*100.0 << endl;
			rectangle(frame_copy, Point(x, y), Point(x + 64, y + 128), Scalar(0,0,200), 2); //x,y //Scaler = B,G,R
			cv::putText(frame_copy, tostr(proba * 100.0), cv::Point(x,y-5), 5, 0.5, cv::Scalar(255.0,0,0), 1, CV_AA, false);
		}
		cnt++;
	}
	imwrite("result.png", frame_copy);
	//imshow("result", frame_copy);
	bool err = false;
	if(!err) return 0;
	else return -1;
}
