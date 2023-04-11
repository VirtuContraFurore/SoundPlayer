

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
	
);

	/* Params */
	`include "../buffer_consts.v"
	localparam WAIT = 2'd0;
	localparam READ = 2'd1;
	

	
	/*ports definition*/
  
	input  	master_clock;					//203.2128 MHz
	input  	buffer_filled_i;
	input  	reset_n;
	input 	[15:0]buffer_data_in;
	
	output	[BUFFER_ADDR_BITS-1:0]address;   
	output 	I2S_BCLK;						//3.175 MHz	
	output 	I2S_DACDAT;
	output 	I2S_DACLRC;						//44.1 KHz
	output 	buffer_empty_o;
	output  buffer_sel_o;
	
	
	/*private reg  definition*/
	
	
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
	wire BCLK;

divisoreinfrequenzaI2S divisoreinfrequenzaI2S (.master_clock(master_clock), .reset_n(reset_n), .clk_I2S(BCLK));
assign I2S_BCLK = BCLK | I2S_BCLK_en ;


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




