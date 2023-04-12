module Codec_config (
    clk,
    rst_n,
    i2c_sclk,
    i2c_sdat
);

`include "../globals.v"

/* Params */
localparam CLK_Freq = `MAIN_CLK_FREQ_MHZ * 1000 * 1000;
localparam I2C_Freq = `I2C_IF_FREQ_KHZ * 1000;

/* Lut index */
localparam Dummy_DATA	=	0;
localparam SET_LIN_L	=	1;
localparam SET_LIN_R	=	2;
localparam SET_HEAD_L	=	3;
localparam SET_HEAD_R	=	4;
localparam A_PATH_CTRL	=	5;
localparam D_PATH_CTRL	=	6;
localparam POWER_ON	    =	7;
localparam SET_FORMAT	=	8;
localparam SAMPLE_CTRL	=	9;
localparam SET_ACTIVE	=	10;
localparam LUT_SIZE	    =	11;
localparam VOL = 7'd120;

/* Ports definition */
input  clk;
input  rst_n;
output i2c_sclk;
inout  i2c_sdat;

/* Internal regs */
reg	[15:0]	mI2C_CLK_DIV;
reg	[23:0]	mI2C_DATA;
reg			mI2C_CTRL_CLK;
reg			mI2C_GO;
reg	[15:0]	LUT_DATA;
reg	[3:0]	LUT_INDEX;
reg	[1:0]	mSetup_ST;

/* Internal wires */
wire mI2C_END;
wire mI2C_ACK;

I2C_Controller mI2C ( 	
    .CLOCK(mI2C_CTRL_CLK),
    .RESET(rst_n),
        
    .GO(mI2C_GO),
    .END(mI2C_END),
    .ACK(mI2C_ACK),	
    .I2C_DATA(mI2C_DATA),
    
    .I2C_SCLK(i2c_sclk),
    .I2C_SDAT(i2c_sdat)
);

/* I2C Control Clock */
always@(posedge clk)
begin
    if(!rst_n)
    begin
        mI2C_CTRL_CLK	<=	0;
        mI2C_CLK_DIV	<=	0;
    end
    else
    begin
        if( mI2C_CLK_DIV < (CLK_Freq/I2C_Freq) )
            mI2C_CLK_DIV <= mI2C_CLK_DIV+16'd1;
        else begin
            mI2C_CLK_DIV  <= 0;
            mI2C_CTRL_CLK <= ~mI2C_CTRL_CLK;
        end
    end
end

always@(posedge mI2C_CTRL_CLK or negedge rst_n) begin
    if(!rst_n) begin
        LUT_INDEX	<=	0;
        mSetup_ST	<=	0;
        mI2C_GO		<=	0;
    end else begin
        if(LUT_INDEX<LUT_SIZE)
            case(mSetup_ST)
                0:	begin
                    mI2C_DATA	<=	{8'h34,LUT_DATA};
                    mI2C_GO		<=	1;
                    mSetup_ST	<=	1;
                end
                1:	begin
                    if(mI2C_END) begin
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

always begin
	case(LUT_INDEX)
        Dummy_DATA	:	LUT_DATA	<=	16'h0000;
        SET_LIN_L	:	LUT_DATA	<=	16'h0000;
        SET_LIN_R	:	LUT_DATA	<=	16'h0200;
        SET_HEAD_L	:	LUT_DATA	<=	{8'h04,1'b1,VOL};
        SET_HEAD_R	:	LUT_DATA	<=	{8'h06,1'b1,VOL};
        A_PATH_CTRL	:	LUT_DATA	<=	16'h0812;
        D_PATH_CTRL	:	LUT_DATA	<=	16'h0A04;
        POWER_ON	:	LUT_DATA	<=	16'h0C00;
        SET_FORMAT	:	LUT_DATA	<=	16'h0E02;
        SAMPLE_CTRL	:	LUT_DATA	<=	16'h1022;
        SET_ACTIVE	:	LUT_DATA	<=	16'h1201;
        default		:	LUT_DATA	<=	16'h0000;
	endcase
end

endmodule