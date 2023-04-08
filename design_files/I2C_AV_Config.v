module I2C_AV_Config (iCLK,iRST_N,iVOL,I2C_SCLK,I2C_SDAT);   //primi 2 sono lato host(clock e reset), i secondi 2 sono lato I2C 
//	Host Side
input		iCLK;
input		iRST_N;
input		iVOL;
//	I2C Side
output		I2C_SCLK;
inout		I2C_SDAT;
//	Internal Registers/Wires
reg	[15:0]	mI2C_CLK_DIV;
reg	[23:0]	mI2C_DATA;
reg			mI2C_CTRL_CLK;
reg			mI2C_GO;
wire		mI2C_END;
wire		mI2C_ACK;
reg	[15:0]	LUT_DATA;
reg	[3:0]	LUT_INDEX;
reg	[1:0]	mSetup_ST;
reg	[6:0]	VOL;

//	Clock Setting
parameter	CLK_Freq	=	50000000;	//	50	MHz
parameter	I2C_Freq	=	20000;		//	20	KHz
//	LUT Data Number
parameter	LUT_SIZE	=	11;
//	Audio Data Index
parameter	Dummy_DATA	=	0;
parameter	SET_LIN_L	=	1;
parameter	SET_LIN_R	=	2;
parameter	SET_HEAD_L	=	3;
parameter	SET_HEAD_R	=	4;
parameter	A_PATH_CTRL	=	5;
parameter	D_PATH_CTRL	=	6;
parameter	POWER_ON	=	7;
parameter	SET_FORMAT	=	8;
parameter	SAMPLE_CTRL	=	9;
parameter	SET_ACTIVE	=	10;

/////////////////////	I2C Control Clock	////////////////////////
always@(posedge iCLK or negedge iRST_N)
begin
	if(!iRST_N)
	begin
		mI2C_CTRL_CLK	<=	0;
		mI2C_CLK_DIV	<=	0;
	end
	else
	begin
		if( mI2C_CLK_DIV	< (CLK_Freq/I2C_Freq) )
		mI2C_CLK_DIV	<=	mI2C_CLK_DIV+16'd1;
		else
		begin
			mI2C_CLK_DIV	<=	0;
			mI2C_CTRL_CLK	<=	~mI2C_CTRL_CLK;
		end
	end
end
////////////////////////////////////////////////////////////////////
I2C_Controller 	u0	(	.CLOCK(mI2C_CTRL_CLK),		//	Controller Work Clock
						.I2C_SCLK(I2C_SCLK),		//	I2C CLOCK
 	 	 	 	 	 	.I2C_SDAT(I2C_SDAT),		//	I2C DATA
						.I2C_DATA(mI2C_DATA),		//	DATA:[SLAVE_ADDR,SUB_ADDR,DATA]
						.GO(mI2C_GO),      			//	GO transfor
						.END(mI2C_END),				//	END transfor 
						.ACK(mI2C_ACK),				//	ACK
						.RESET(iRST_N)	);
////////////////////////////////////////////////////////////////////
//////////////////////	Config Control	////////////////////////////
always@(posedge mI2C_CTRL_CLK or negedge iRST_N)
begin
	if(!iRST_N)
	begin
		LUT_INDEX	<=	0;
		mSetup_ST	<=	0;
		mI2C_GO		<=	0;
	end
	else
	begin
		if(LUT_INDEX<LUT_SIZE)
		begin
			case(mSetup_ST)
			0:	begin
					mI2C_DATA	<=	{8'h34,LUT_DATA};
					mI2C_GO		<=	1;
					mSetup_ST	<=	1;
				end
			1:	begin
					if(mI2C_END)
					begin
						if(!mI2C_ACK)
						mSetup_ST	<=	2;
						else
						mSetup_ST	<=	0;							
						mI2C_GO		<=	0;
					end
				end
			2:	begin
					LUT_INDEX	<=	LUT_INDEX+4'd1;
					mSetup_ST	<=	0;
				end
			endcase
		end
	end
end
////////////////////////////////////////////////////////////////////
/////////////////////	Config Data LUT	  //////////////////////////
always@(negedge iVOL)
begin
	if(VOL<68)
	VOL		<=	98;
	else
	VOL		<=	VOL+7'd3;
end


	
always
begin
	case(LUT_INDEX)
	//	Audio Config Data
	//Dummy_DATA	:	LUT_DATA	<=	16'h0000;
//	SET_LIN_L	:	LUT_DATA	<=	16'h001A;
//	SET_LIN_R	:	LUT_DATA	<=	16'h021A;
	SET_HEAD_L	:	LUT_DATA	<=	{8'h04,1'b1,VOL};
	SET_HEAD_R	:	LUT_DATA	<=	{8'h06,1'b1,VOL};
//	A_PATH_CTRL	:	LUT_DATA	<=	16'h08F8;
//	D_PATH_CTRL	:	LUT_DATA	<=	16'h0A06;
//	POWER_ON		:	LUT_DATA	<=	16'h0C00;
	//SET_FORMAT	:	LUT_DATA	<=	16'h0E41;
//	SAMPLE_CTRL	:	LUT_DATA	<=	16'h1002;
//	SET_ACTIVE	:	LUT_DATA	<=	16'h1201;
	//default		:	LUT_DATA	<=	16'h0000;
	//	Audio Config Data
	
	
	
	//CONFIGURAZIONE NOSTRA
	Dummy_DATA	:	LUT_DATA	<=	16'h0000;
	SET_LIN_L	:	LUT_DATA	<=	16'h0000;  //r0
	SET_LIN_R	:	LUT_DATA	<=	16'h0200;  //r1
//	SET_HEAD_L	:	LUT_DATA	<=	16'h04D6;  //r2
//	SET_HEAD_R	:	LUT_DATA	<=	16'h06D6;  //r3
	A_PATH_CTRL	:	LUT_DATA	<=	16'h0812;  //r4  
	D_PATH_CTRL	:	LUT_DATA	<=	16'h0A06;  //r5
	POWER_ON	   :	LUT_DATA	<=	16'h0C00;  //r6
	SET_FORMAT	:	LUT_DATA	<=	16'h0E02;  //r7--->01 left just   --->02 i2sleft
	SAMPLE_CTRL	:	LUT_DATA	<=	16'h1022;  //r8
	SET_ACTIVE	:	LUT_DATA	<=	16'h1201;  //r9
default		:	LUT_DATA	<=	16'h0000;
	
	
////////////////////////////////////////////////////////////////////
/////////////////////	Config Data LUT	del file sd card dell 'altera  //////////////////////////	

	
	//	Audio Config Data
	//Dummy_DATA	:	LUT_DATA	<=	16'h0000;
	//SET_LIN_L	:	LUT_DATA	<=	16'h001A;
	//SET_LIN_R	:	LUT_DATA	<=	16'h021A;
	//SET_HEAD_L	:	LUT_DATA	<=	16'h046B;
	//SET_HEAD_R	:	LUT_DATA	<=	16'h066B;
	//A_PATH_CTRL	:	LUT_DATA	<=	16'h0812; //16'h08F8
	//D_PATH_CTRL	:	LUT_DATA	<=	16'h0A06;
	//POWER_ON	:	LUT_DATA	<=	16'h0C00;
	//SET_FORMAT	:	LUT_DATA	<=	16'h0E02;   //prima 16'h0E01 
	//SAMPLE_CTRL	:	LUT_DATA	<=	16'h1022;   //prima 16'h1002
	//SET_ACTIVE	:	LUT_DATA	<=	16'h1201;
	//default		:	LUT_DATA	<=	16'h0000;
	endcase
end
endmodule