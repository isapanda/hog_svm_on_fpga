#define HOG_WIDTH 64
#define HOG_HEIGHT 128
#define CELL_SIZE_ROW 8
#define CELL_SIZE_COL 8
#define BLOCK_SIZE_ROW 2
#define BLOCK_SIZE_COL 2
#define N_CELLS_ROW HOG_HEIGHT/CELL_SIZE_ROW //4
#define N_CELLS_COL HOG_WIDTH/CELL_SIZE_COL //8
#define N_BLOCK_ROW HOG_HEIGHT/(CELL_SIZE_ROW * BLOCK_SIZE_ROW) //2
#define N_BLOCK_COL HOG_WIDTH/(CELL_SIZE_COL * BLOCK_SIZE_COL) //4
#define HISTOGRAMSIZE N_CELLS_ROW * N_CELLS_COL * 9 //4*8*9
struct hogweight{
	ap_fixed<128,106> weightval[9];
};

typedef ap_fixed<32, 10> ap_fixed_point;
typedef ap_fixed<64, 20> accum_fixed;


//typedef float ap_fixed_point;
//typedef float accum_fixed;
