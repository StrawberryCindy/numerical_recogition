module video_process
#(
	parameter DATA_WIDTH = 8,                      // Video data one clock data width
	parameter we = 180,								// vertical end
	parameter he = 240,								// horizontal end

   parameter h1 = 80,                              // horizontal standards
   parameter h2 = 160,
	parameter w1 = 90                               // vertical standard
	 
)
(
	input                       line_clk,        	// Points clk
	input								 video_clk, 			// Video clock
	input                       rst,
	input[we - 1:0]       		 line1,	            // 0-black  1-white
	input[we - 1:0]      		 line2,

	input[DATA_WIDTH - 1:0]		 h,						// row
	output reg[3:0]              vout_num,            // the number in video
	output reg[3:0]					 point_num1,
	output reg[3:0]					 point_num2,
	output reg[3:0]					 point_num3
);

reg					  		frame_flag;		 // A frame of data is ready

//------------------------------------
//------------------------------------

reg[3:0]                point_num1_d0;
reg[3:0]                point_num2_d0;
reg[3:0]                point_num3_d0;
reg[7:0]	    	   		tick;

reg[4:0]						state;
reg[4:0]						next_state;

//reg[3:0]						vout_num_r;

reg                    	flag1;       // left above
reg		               flag2;       // right below
reg 				   		flag3 = 0;		// right center 
reg					 	   position1 = 0;	// right h2
reg		               position2 = 0;   // left h1 

wire[11:0]					point_num;
//assign				vout_num = vout_num_r;
assign				point_num[11:8] = (point_num1 + 1'b1) >> 1;
assign				point_num[7:4] = (point_num2 + 1'b1) >> 1;
assign				point_num[3:0] = (point_num3 + 1'b1) >> 1;

parameter	idle = 5'd0;
parameter	ready = 5'd1;
parameter   check = 5'd2;

always@(posedge video_clk or posedge rst)
begin
	if(rst == 1'b1)
	begin
		state<=idle;
	end
	else
		state<=next_state;
end

always@(*) //模块内所有东西变化就触发
begin
 	case(state)
		idle	:	begin												
						if(line_clk == 1'b1)
							next_state <= ready;
						else
							next_state <= idle;
					end
		ready	: 	begin						
						if(tick == we-1)
						begin
							if(h == he-1)
								next_state <= check;					
							else 	
								next_state <= idle;					
						end
						else
							next_state <= ready;						
					end
		check	:	begin
						next_state <= idle;	
					end					
	default	:	next_state <= idle;
	endcase;
end

//对tick的判断
always@(posedge video_clk or posedge rst)
begin
	if(rst == 1'b1)
		tick <= 8'b1;
	else if(state == ready)
		tick <= tick + 8'b1;
	else tick <= 8'b1;
end

//对point_number1d0的判断
always@(posedge video_clk or posedge rst)
begin
	if(rst == 1'b1)
		point_num1_d0 <= 4'b0;		
	else if(state == ready)
	begin
		if (h == h1 && (line1[tick]^line1[tick-1]) == 1 )
		begin
			if(point_num1_d0 != 4'hf)
				point_num1_d0 <= point_num1_d0+4'b1;
		end
		else 
			point_num1_d0 <= point_num1_d0;
	end
	else if(state == idle)
		point_num1_d0 <= point_num1_d0;
	else 
		point_num1_d0 <= 4'd0;
end

//对point_number2d0的判断
always@(posedge video_clk or posedge rst)
begin
	if(rst == 1'b1)
		point_num2_d0 <= 4'b0;		
	else if(state == ready)
	begin
		if (h == h2 && (line1[tick]^line1[tick-1]) == 1 )
		begin
			if(point_num2_d0 != 4'hf)
				point_num2_d0 <= point_num2_d0+4'b1;
		end
		else 
			point_num2_d0 <= point_num2_d0;
	end
	else if(state == idle)
		point_num2_d0 <= point_num2_d0;
	else 
		point_num2_d0 <= 4'd0;
end

//对point_number3d0的判断
always@(posedge video_clk or posedge rst)
begin
	if(rst == 1'b1)
		point_num3_d0 <= 4'b0;		
	else if(state == ready)
	begin
		if (tick == w1 && (line1[tick]^line2[tick]) == 1 )
		begin
			if(point_num3_d0 != 4'hf)
				point_num3_d0 <= point_num3_d0+4'b1;
		end
		else 
			point_num3_d0 <= point_num3_d0;
	end
	else if(state == idle)
		point_num3_d0 <= point_num3_d0;
	else 
		point_num3_d0 <= 4'd0;
end

//对point_number的判断
always@(posedge video_clk or posedge rst)
begin
	if(rst == 1'b1)
	begin
		point_num1 <= 4'b0;
		point_num2 <= 4'b0;
		point_num3 <= 4'b0;		
	end
	else if(state == check)
	begin
		point_num1 <= point_num1_d0;
		point_num2 <= point_num2_d0;
		point_num3 <= point_num3_d0;
	end
	else
	begin
		point_num1 <= point_num1;
		point_num2 <= point_num2;
		point_num3 <= point_num3;
	end
end



always@(posedge video_clk or posedge rst)
begin
	if (rst == 1'b1)
		vout_num <= 4'hf;
	else if (state == check)
	begin		
		case(point_num)			
			12'b0010_0010_0010: 		vout_num <= 0;
			12'b0001_0001_0000: 		vout_num <= 1;
			12'b0001_0001_0100, 12'b0010_0001_0100: 
											vout_num <= 3;
			12'b0010_0001_0000, 12'b0010_0001_0001: 	
											vout_num <= 4;
			12'b0001_0010_0011: 		vout_num <= 6;
			12'b0001_0001_0010: 		vout_num <= 7;
			12'b0010_0010_0011, 12'b0010_0010_0100: 	
											vout_num <= 8;
			12'b0011_0001_0010:		vout_num <= 9;
			12'b0001_0001_0001: 		
			begin
				if (flag1) 	vout_num <= 7;
				else		vout_num <= 1;
			end

			12'b0001_0001_0011:
			begin 
				if (position2) 
					vout_num <= 5;
				else if(position1)
					vout_num <= 3;
				else
					vout_num <= 2;
			end

			12'b0010_0001_0011:
			begin
				if (flag2 && position1)	
					vout_num <= 3;
				else if (flag2)
					vout_num <= 2;
				else
					vout_num <= 9;
			end

			12'b0010_0001_0010:
			begin
				if (flag3)	vout_num <= 4;
				else		vout_num <= 9;
			end
			default: vout_num <= 4'hf;
		endcase
	end
	else
		vout_num <= vout_num;
end


//对flag1的判断
reg			b_w60;
reg			b_h80;
always@(posedge video_clk or posedge rst)
begin
	if(rst == 1'b1)
	begin
		flag1 <= 1'b0;	
		b_h80 <= 1'b1;
		b_w60 <= 1'b1;
	end
	else if(state == ready)
	begin
		if (h == h1) 
			b_h80 <= 1'b0;
		else if (tick == 8'd60) 
			b_w60 <= 1'b0;
		else if (tick == 8'd1)
			b_w60 <= 1'b1;
		else if (b_h80 && b_w60 && line2[tick])
			flag1 <= 1'b1;
	end
	else if (state == idle)
	begin
		b_h80 <= b_h80;
		b_w60 <= b_w60;
		flag1 <= flag1;
	end
	else
	begin
		b_h80 <= 1'b1;
		b_w60 <= 1'b1;
		flag1 <= 1'b0;
	end
end

//对flag2的判断
reg			a_w120;
reg			a_h160;
always@(posedge video_clk or posedge rst)
begin
	if(rst == 1'b1)
	begin
		flag2 <= 1'b0;	
		a_h160 <= 1'b0;
		a_w120 <= 1'b0;
	end
	else if(state == ready)
	begin
		if (h == 8'd160) 
			a_h160 <= 1'b1;
		else if (tick == 8'd120) 
			a_w120 <= 1'b1;
		else if (tick == 8'd1)
			a_w120 <= 1'b0;
		else if (a_h160 && a_w120 && line2[tick])
			flag2 <= 1'b1;
	end
	else if (state == idle)
	begin
		a_h160 <= a_h160;
		a_w120 <= a_w120;
		flag2 <= flag2;
	end
	else
	begin
		a_h160 <= 1'b0;
		a_w120 <= 1'b0;
		flag2 <= 1'b0;
	end
end


//对flag3的判断
reg			c_w120;
reg			c_h1_h2;
always@(posedge video_clk or posedge rst)
begin
	if(rst == 1'b1)
	begin
		flag3 <= 1'b0;	
		c_h1_h2 <= 1'b0;
		c_w120 <= 1'b0;
	end
	else if(state == ready)
	begin
		if (h == h1) 
			c_h1_h2 <= 1'b1;
		else if (tick == 8'd60) 
			c_w120 <= 1'b1;
		else if (tick == 8'd1)
			c_w120 <= 1'b0;
		else if (h == h2)
			c_h1_h2 <= 1'b0;
		else if (c_h1_h2 && c_w120 && line2[tick])
			flag3 <= 1'b1;
	end
	else if (state == idle)
	begin
		c_h1_h2 <= c_h1_h2;
		c_w120 <= c_w120;
		flag3 <= flag3;
	end
	else
	begin
		c_h1_h2 <= 1'b0;
		c_w120 <= 1'b0;
		flag3 <= 1'b0;
	end
end

//position1的判断
reg	right_h2;
always@(posedge video_clk or posedge rst)
begin
	if (rst)
	begin
		position1<= 1'b0;
		right_h2 <= 1'b0;
	end
	else if (state == ready)
	begin
		if (h == h2 && tick == 8'd90)
			right_h2 <= 1'b1;
		else if (tick == 1)
			right_h2 <= 1'b0;
		else if (right_h2 && line2[tick])
			position1 <= 1'b1;
	end
	else if (state == idle)
	begin
		position1<= position1;
		right_h2 <= right_h2;
	end
	else
	begin
		position1<= 1'b0;
		right_h2 <= 1'b0;
	end
end

//position2的判断
reg	left_h1;
always@(posedge video_clk or posedge rst)
begin
	if (rst)
	begin
		position2<= 1'b0;
		left_h1 <= 1'b0;
	end
	else if (state == ready)
	begin
		if (h == h1 && tick == 8'd1)
			left_h1 <= 1'b1;
		else if (tick == 8'd90)
			left_h1 <= 1'b0;
		else if (left_h1 && line2[tick])
			position2 <= 1'b1;
	end
	else if (state == idle)
	begin
		position2<= position2;
		left_h1 <= left_h1;
	end
	else
	begin
		position2<= 1'b0;
		left_h1 <= 1'b0;
	end

end
endmodule 

