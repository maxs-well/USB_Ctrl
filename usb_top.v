module usb_top(
	input						clk_in			,
	input						rst_n				,
	input						usb_n_ept_to	,	/*FIFO2 empty*/
	input						usb_n_ept_fr	,	/*FIFO4 empty*/
	input						usb_n_ful_sx	,	/*FIFO6 full */
	inout	[15:0]			usb_data			,
	
	output					usb_slcs			,	/* chipselect */
	output					usb_sloe			,	/* data output enable */
	output					usb_slrd			,	/* read indicate */
	output					usb_slwr			,	/* write req */
	output			[ 1:0]usb_addr			
);
reg 	[10:0]rd_wr_num	;
reg 	[1:0]	rd_wr_en	;
wire 			usb_is_busy;
wire 	[15:0]read_data;
reg  	[15:0]write_data;
wire 			output_valid;
wire			write_ready;

pll pll_inst(
	.inclk0(clk_in),
	.c0(clk)
);

always @ (posedge clk or negedge rst_n)
begin
	if (!rst_n)
	begin
		rd_wr_num <= 'd0;
		rd_wr_en	 <= 'd0;
		write_data<= 'd0;
	end
	else 
	begin
		rd_wr_num <=	11'd4;
		
		if (!usb_is_busy)
			rd_wr_en <=	2'b10;
		
//		if (!usb_is_busy)
//			rd_wr_en <= 2'b01;
//		write_data <= write_data + 16'd1;
	end
end	
		
usb_ctrl 
#(
	.LOOP_WORK (0)	,
	.AUTO_WORK (0)	,
	.TS_NUM	(4)
)
usb_inst
(
	/* FPGA main interface */
	.clk		(clk),
	.rst_n	(rst_n),
	/* USB FIFO Indication*/
	.usb_n_ept_to	(usb_n_ept_to),	/*FIFO2 empty*/
	.usb_n_ept_fr	(usb_n_ept_fr),	/*FIFO4 empty*/
	.usb_n_ful_sx	(usb_n_ful_sx),	/*FIFO6 full */
	.usb_data		(usb_data)	  ,
	/* device ctrl */
	.rd_wr_num		(rd_wr_num		)	,	/* the number of read or write data  */	
	.rd_wr_en		(rd_wr_en		)	,  /* 10 -> read or 01 -> write */
	.usb_is_busy	(usb_is_busy	)	,  
	.read_data		(read_data		)	,
	.write_data		(write_data		)	,
	.output_valid	(output_valid	)	,
	.write_ready	(write_ready	)	,
	/* USB Ctrl Signal*/
	.usb_slcs	(usb_slcs),	/* chipselect */
	.usb_sloe	(usb_sloe),	/* data output enable */
	.usb_slrd	(usb_slrd),	/* read indicate */
	.usb_slwr	(usb_slwr),	/* write req */
	.usb_addr	(usb_addr)
);

endmodule
