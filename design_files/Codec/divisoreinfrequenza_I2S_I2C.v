module divisorefrequenza_I2S_I2C(clk_I2S,clk_I2C,reset_n,master_clock);
input master_clock,reset_n;
output clk_I2S, clk_I2C;
reg [15:0]count;

always@(posedge master_clock)
begin
if(reset_n==0)count<=0;
else if (count==16'b1111111111111111) count<=16'b0000000000000000;
else count<=count+1'b1;
end

assign clk_I2S = count[5];
assign clk_I2C = count[9];


endmodule