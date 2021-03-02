module seg_test(
    input[3:0]      bin_num,
    output[5:0]     seg_sel,
    output[7:0]     seg_data
);

reg[7:0]			seg_data_0;
reg[5:0]			seg_sel_0;
assign			seg_data = seg_data_0;
assign			seg_sel = seg_sel_0;

always@(*)
begin
	seg_sel_0 <= 6'b111110;
	case(bin_num)
		4'd0:seg_data_0 <= 8'b1100_0000;
		4'd1:seg_data_0 <= 8'b1111_1001;
		4'd2:seg_data_0 <= 8'b1010_0100;
		4'd3:seg_data_0 <= 8'b1011_0000;
		4'd4:seg_data_0 <= 8'b1001_1001;
		4'd5:seg_data_0 <= 8'b1001_0010;
		4'd6:seg_data_0 <= 8'b1000_0010;
		4'd7:seg_data_0 <= 8'b1111_1000;
		4'd8:seg_data_0 <= 8'b1000_0000;
		4'd9:seg_data_0 <= 8'b1001_0000;
		4'ha:seg_data_0 <= 8'b1000_1000;
		4'hb:seg_data_0 <= 8'b1000_0011;
		4'hc:seg_data_0 <= 8'b1100_0110;
		4'hd:seg_data_0 <= 8'b1010_0001;
		4'he:seg_data_0 <= 8'b1000_0110;
		4'hf:seg_data_0 <= 8'b1000_1110;
		default:seg_data_0 <= 8'b1111_1111;
	endcase
end

endmodule 