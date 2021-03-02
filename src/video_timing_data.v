//////////////////////////////////////////////////////////////////////////////////
//                                                                              //
//                                                                              //
//  Author: meisq                                                               //
//          msq@qq.com                                                          //
//          ALINX(shanghai) Technology Co.,Ltd                                  //
//          heijin                                                              //
//     WEB: http://www.alinx.cn/                                                //
//     BBS: http://www.heijin.org/                                              //
//                                                                              //
//////////////////////////////////////////////////////////////////////////////////
//                                                                              //
// Copyright (c) 2017,ALINX(shanghai) Technology Co.,Ltd                        //
//                    All rights reserved                                       //
//                                                                              //
// This source file may be used and distributed without restriction provided    //
// that this copyright statement is not removed from the file and that any      //
// derivative work contains the original copyright notice and the associated    //
// disclaimer.                                                                  //
//                                                                              //
//////////////////////////////////////////////////////////////////////////////////

//================================================================================
//  Revision History:
//  Date          By            Revision    Change Description
//--------------------------------------------------------------------------------
//  2017/7/19     meisq          1.0         Original
//*******************************************************************************/

module video_timing_data
#(
	parameter DATA_WIDTH = 16                       // Video data one clock data width
)
(
	input                       video_clk,          // Video pixel clock
	input                       rst,
	output reg                  read_req,           // Start reading a frame of data     
	input                       read_req_ack,       // Read request response
	output                      read_en,            // Read data enable
	input[DATA_WIDTH - 1:0]     read_data,          // Read data
	output                      hs,                 // horizontal synchronization
	output                      vs,                 // vertical synchronization
	output                      de,                 // video valid
	output[DATA_WIDTH - 1:0]    vout_data,          // video data
	
	output reg[179:0]           line1,              // data_line1 for recognize
	output reg[179:0]           line2,              // data_line2 for recognize
	output reg                  prepared,           // data_prepared
	output reg[7:0] 	          row                 // row for recognize
);

//用于灰度转换的参数
parameter r2gray = 10'd47;  
parameter g2gray = 10'd157; 
parameter b2gray = 10'd16; 
parameter para_16_18b=10'd4096;
//各种状态
parameter idle=3'd0;
parameter y_pre=3'd1;
parameter x_pre=3'd2;
parameter pupdate=3'd3;
parameter update=3'd4;
parameter cnt_add=3'd5;


wire                   video_hs;
wire                   video_vs;
wire                   video_de;
wire[11:0]				  active_x;
wire[11:0]				  active_y;
wire[15:0]             read_data2gray;
wire		              read_data2binary1b;
wire[7:0]              y2b_tmp;
wire[15:0]             read_data2binary565;
wire[7:0]              r;
wire[7:0]              g;
wire[7:0]              b;
wire[17:0]       		  result_y_18b;
wire[7:0]       		  y_tmp;


//腐蚀暂存数组
reg [181:0] temline1;
reg [181:0] temline2;
reg [181:0] temline3;
reg [11:1] tmp3_cnt;
wire [181:0] temline4;
wire zero;
wire [181:0] temline5;
//状态机
reg [2:0] state;
reg [2:0] next_state;
reg [3:0] row_cnt;
//delay video_hs video_vs  video_de 2 clock cycles
reg                    video_hs_d0;//为了能读到sdram的数据做第一次延迟
reg                    video_vs_d0;//为了能读到sdram的数据做第一次延迟
reg                    video_de_d0;//为了能读到sdram的数据做第一次延迟
reg[11:0]				  active_x_d0;
reg[11:0]				  active_y_d0;
reg                    video_hs_d1;//为了给外界检测到信号时数据有效做第二次延迟
reg                    video_vs_d1;//为了给外界检测到信号时数据有效做第二次延迟
reg                    video_de_d1;//为了给外界检测到信号时数据有效做第二次延迟

reg[DATA_WIDTH - 1:0]  vout_data_r;

//temline5[180:1]为有用分量
assign zeros = 1'b0;
assign temline4 = temline1|temline2|temline3;
assign temline5 = {temline4}|{zero,temline4[181:1]}|{temline4[180:0],zero};

//rgb888分量
assign r={read_data[15:11],3'd0};
assign g={read_data[10:5],2'd0};
assign b={read_data[4:0],3'd0};
assign result_y_18b=r*r2gray+g*g2gray+b*b2gray+para_16_18b;
assign y_tmp = result_y_18b[17:8] + {9'd0,result_y_18b[7]};//四舍五入
assign read_data2gray = {y_tmp[7:3],y_tmp[7:2],y_tmp[7:3]};//灰度图像
assign read_data2binary1b = y_tmp>80 ? 0:1;//二值化图
assign y2b_tmp =read_data2binary1b ? 255:0;
assign read_data2binary565 ={y2b_tmp[7:3],y2b_tmp[7:2],y2b_tmp[7:3]};//灰度图像


assign read_en = video_de;
assign hs = video_hs_d1;
assign vs = video_vs_d1;
assign de = video_de_d1;
assign vout_data = vout_data_r;


//按键状态机部分-------------------------------------
always@(posedge video_clk or posedge rst)
begin
	if(rst == 1'b1)
	begin
		state<=idle;
	end
	else
		state<=next_state;
end

parameter x_roi_begin = 12'd421;
parameter y_roi_begin = 12'd264;
parameter x_roi_end = 12'd603;
parameter y_roi_end = 12'd506;

//x 1-1024    1024-180=844  422     1-422   423-602   603-1024

//y 1-768     768-240 =528  264     1-264   265-504   505-768
always@(*) //模块内所有东西变化就触发
begin
 	case(state)
		idle	:	begin						
						if(active_y_d0 == y_roi_begin)
							next_state <= y_pre;
						else
							next_state <= idle;
					end
		y_pre	: 	begin						
						if(active_x_d0 == x_roi_begin)
							next_state <= x_pre;
						else if(active_y_d0 == y_roi_end)
							next_state <= idle;
						else
							next_state <= y_pre;
					end
		x_pre	:	begin
						if(active_x_d0 == x_roi_end)
						begin
							if(row_cnt == 4'd3)
								next_state <= update;
							else	if(row_cnt == 4'd2)			
								next_state <= pupdate;
							else
								next_state <= cnt_add;
						end
						else
								next_state <= x_pre;
					end	
		update:	begin						
						next_state <= y_pre;
					end
		pupdate:	begin						
						next_state <= y_pre;
					end
		cnt_add:	begin						
						next_state <= y_pre;
					end
	default	:	next_state <= idle;
	endcase;
end
//对prepared的判断值
always@(posedge video_clk or posedge rst)
begin	
	if(rst == 1'b1)
	begin
		prepared <= 1'b0;
	end
	else if(state == update)
		prepared <= 1'b1;
	else 
		//prepared <= prepared;
		prepared <= 1'b0;
end

//对line1,line2的判断值
always@(posedge video_clk or posedge rst)
begin	
	if(rst == 1'b1)
	begin
		line1 <= 180'b0;
		line2 <= 180'b0;
		row <= 8'b0; 
	end
	else if(state == pupdate)
	begin
		line1 <= line2;
		line2 <= temline5[180:1];
		row <= row;
	end
	else if(state == update)
	begin
		line1 <= line2;
		line2 <= temline5[180:1];		
		row <= row + 8'b1; 
	end
	else if(state == idle)
	begin
		line1 <= 180'b0;
		line2 <= 180'b0;
		row <= 8'b0;
	end
	else 
	begin
		line1 <= line1;
		line2 <= line2;
		row <= row;
	end
end

//对y_cnt的判断值
always@(posedge video_clk or posedge rst)
begin	
	if(rst == 1'b1)
	begin
		row_cnt <= 3'd0;
	end
	else if(state == cnt_add)
	begin
		if (row_cnt != 3'd3)
			row_cnt <= row_cnt + 3'd1;
	end
	else if(state == pupdate)
	begin
		if (row_cnt != 3'd3)
			row_cnt <= row_cnt + 3'd1;
			
	end
	else if(state == idle)
	begin
		row_cnt <= 3'd0;
	end
	else
		row_cnt <= row_cnt ;
end

//对temline3的行处理
always@(posedge video_clk or posedge rst)
begin	
	if(rst == 1'b1)
	begin
		temline3 <= 182'b0;
		tmp3_cnt <= 11'b0;
	end
	else if(state == x_pre)
	begin
		if(video_de_d0)
		begin
			temline3[tmp3_cnt] <= read_data2binary1b;
			tmp3_cnt <= tmp3_cnt+1;
		end
		else
		begin
			temline3[tmp3_cnt] <= temline3[tmp3_cnt];
			tmp3_cnt <= tmp3_cnt;
		end
	end
	else	
	begin
		temline3 <= 182'b0;
		tmp3_cnt <= 11'b0;
	end;
end

//结束


//对temline1,2的行处理
always@(posedge video_clk or posedge rst)
begin	
	if(rst == 1'b1)
	begin
		temline1 <= 182'b0;
		temline2 <= 182'b0;
	end
	else if(state == cnt_add||state == pupdate||state == update)
	begin
		temline2 <= temline3;
		temline1 <= temline2;	
	end
	else	
	begin
		temline2 <= temline2;
		temline1 <= temline1;		
	end;
end

//结束


always@(posedge video_clk or posedge rst)
begin
	if(rst == 1'b1)
	begin
		video_hs_d0 <= 1'b0;
		video_vs_d0 <= 1'b0;
		video_de_d0 <= 1'b0;
		active_x_d0	<=1'b0;
		active_y_d0 <=1'b0;
	end
	else
	begin
		//delay video_hs video_vs  video_de 2 clock cycles
		video_hs_d0 <= video_hs;
		video_vs_d0 <= video_vs;
		video_de_d0 <= video_de;
		video_hs_d1 <= video_hs_d0;
		video_vs_d1 <= video_vs_d0;
		video_de_d1 <= video_de_d0;
		active_x_d0	<= active_x;
		active_y_d0 <= active_y;
	end
end

always@(posedge video_clk or posedge rst)
begin
	if(rst == 1'b1)
		vout_data_r <= {DATA_WIDTH{1'b0}};
	else if(video_de_d0)
	begin
		if(state==x_pre)
			vout_data_r <= read_data2binary565;
		else
			vout_data_r <= read_data;
	end
	else
		vout_data_r <= {DATA_WIDTH{1'b0}};
end

always@(posedge video_clk or posedge rst)
begin
	if(rst == 1'b1)
		read_req <= 1'b0;
	else if(video_vs_d0 & ~video_vs) //vertical synchronization edge (the rising or falling edges are OK)
		read_req <= 1'b1;
	else if(read_req_ack)
		read_req <= 1'b0;
end

color_bar color_bar_m0(
	.clk(video_clk),
	.rst(rst),
	.hs(video_hs),
	.vs(video_vs),
	.de(video_de),
	.rgb_r(),
	.rgb_g(),
	.rgb_b(),
	.active_x(active_x),              //video x position 
	.active_y(active_y)              //video y position 
);
endmodule 