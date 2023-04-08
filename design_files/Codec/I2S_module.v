

module I2S_module (
	master_clock,
	buffer_filled_i,
	reset_n,
	buffer_data_in,
	
	address,
	I2S_BCLK,
	I2S_DACDAT,
	I2S_DACLRC,
	buffer_empty_o,
	buffer_sel_o,
	
	//HEX
);

	/* Params */
	`include "../buffer_consts.v";
	localparam WAIT = 2'd0;
	localparam READ = 2'd1;
	

	
	/*ports definition*/
	
	//input 	[7:0] sw;  
	input  	master_clock;	//203.2128 MHz
	input  	buffer_filled_i;
	input  	reset_n;
	input 	[15:0]buffer_data_in;
	
	output	[BUFFER_ADDR_BITS-1:0]address;   
	//output   [0:15]HEX;
	output 	I2S_BCLK;		//3.175 MHz	
	output 	I2S_DACDAT;
	output 	I2S_DACLRC;		//44.1 KHz
	output 	buffer_empty_o;
	output  buffer_sel_o;
	
	
	/*private reg  definition*/
	
	//reg      	[191:0]MEMORY2;
	//reg      	[127:0]MEMORY3;
	//reg      	[0:15]HEX;
	//integer 	crusca;
	
	reg 		[BUFFER_ADDR_BITS-1:0]address;
	reg      	[15:0]data_in;
    reg      	I2S_BCLK_en;
	reg 		I2S_DACLRC;
	reg 		I2S_DACDAT;
	reg 		buffer_empty_o;
	reg			buffer_sel_o;
	reg 		[1:0]STATUS;
	integer 	rd_counter,idato;
	
	/*private wire  definition*/
	wire 		BCLK; 
	

//TODO: Since the I2C and I2S will be instantieted in codec.v and both need a prescaler  it is better to add an output to this prescaler and move it on codec.v
divisorefrequenzaI2S divisorefrequenzaI2S (.master_clock(master_clock), .reset_n(reset_n), .clk_out(BCLK));  //divides the masterclock by 64

assign I2S_BCLK = BCLK | I2S_BCLK_en ;

	
//DEBUG -------------------------------------------------------------------
//always@(posedge master_clock)   
//	begin
//		if(reset_n==0)
//			begin
//				HEX[0:15]<=16'd0;
//			end	
//		else
//		begin
//		case(sw)
//		1:HEX[0:15]<=MEMORY2[15:0];
//		2:HEX[0:15]<=MEMORY2[31:16];
//		3:HEX[0:15]<=MEMORY2[47:32];
//		4:HEX[0:15]<=MEMORY2[63:48];
//		5:HEX[0:15]<=MEMORY2[79:64];
//		6:HEX[0:15]<=MEMORY2[95:80];
//		7:HEX[0:15]<=MEMORY2[111:96];
//		8:HEX[0:15]<=MEMORY2[127:112];
//		9:HEX[0:15]<=MEMORY2[143:128];
//		10:HEX[0:15]<=MEMORY2[159:144];
//		11:HEX[0:15]<=MEMORY2[175:160];
//	   12:HEX[0:15]<=MEMORY2[191:176];
//		
//		default:HEX[0:15]<=16'd0;
//		endcase
//		end
//end	
//------------------------------------------------------------------------------------

	always @(negedge BCLK)
begin

	if(reset_n==0)
		begin
		buffer_empty_o<=0;
		address<=9'd0;
		I2S_DACDAT<=1;
		I2S_DACLRC<=1;
		idato<=0;
		rd_counter<=0;
		STATUS<=WAIT;
		I2S_BCLK_en<=1;
		buffer_sel_o<=0;
		end
	else
	begin
		case(STATUS)   
		WAIT: if(buffer_filled_i==1)STATUS<=READ; 											
		READ:
		    begin
					////DEBUG-------------------------------------------	
					//if(crusca==0 && idato==0)MEMORY2[15:0]<=buffer_data_in;
					//else if(crusca==1 && idato==0)MEMORY2[31:16]<=buffer_data_in;
					//else if(crusca==255 && idato==0)MEMORY2[47:32]<=buffer_data_in;
					//else if(crusca==256 && idato==0)MEMORY2[63:48]<=buffer_data_in;
					//else if(crusca==511 && idato==0)MEMORY2[79:64]<=buffer_data_in;
					//else if(crusca==512 && idato==0)MEMORY2[95:80]<=buffer_data_in;
					//else if(crusca==767 && idato==0)MEMORY2[111:96]<=buffer_data_in;
					//else if(crusca==768 && idato==0)MEMORY2[127:112]<=buffer_data_in;
					//else if(crusca==1023 && idato==0)MEMORY2[143:128]<=buffer_data_in;
					//else if(crusca==1024 && idato==0)MEMORY2[159:144]<=buffer_data_in;
					//else if(crusca==1279 && idato==0)MEMORY2[175:160]<=buffer_data_in;
					//else if(crusca==1280 && idato==0)MEMORY2[191:176]<=buffer_data_in;
					
					//------------------------------------------------------------------
					I2S_BCLK_en <= 0;
					idato<=idato+32'd1;
					if(idato==0)
						begin
						I2S_DACDAT <=0;
						data_in<=buffer_data_in;
						end
					if(idato==1)
						begin
						buffer_empty_o<=0;
						end
					if(idato==31)address<=address+1;
					if(idato>0 && idato<9) 
								begin
								I2S_DACDAT <= data_in[8-idato];
								end
					if(idato>8 && idato<17)
								begin
								I2S_DACDAT <= data_in[24-idato];
								end
					if(idato>16 && idato<37)I2S_BCLK_en<=1;   			//data trasmission has finished 
					if(idato==36)
					begin		
						idato<=0;
						if(I2S_DACLRC==0)								//stupid way to toggle I2S_DACLRC 
							begin
								I2S_DACLRC<=1;
							end
						if(I2S_DACLRC==1)
							begin
								I2S_DACLRC<=0;
							end
						
						if(rd_counter==BUFFER_SIZE_BYTES)				//end of the buffer
							begin
								rd_counter<=0;
								buffer_empty_o<=1;
								buffer_sel_o <= ~buffer_sel_o;
								STATUS<=WAIT;
							end	
						else
						begin
							rd_counter<=rd_counter+1;
						end
		
					end			
			end
		endcase
	end
end



endmodule	




