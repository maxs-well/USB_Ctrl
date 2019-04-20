/*
@author : WoodFan
@date 	: 2019/04/08
@name	: usb_ctrl
@function
** usb driver of ctrol 
*/
module usb_ctrl 
#(
	parameter LOOP_WORK 	= 1	,		//loopback
	parameter AUTO_WORK 	= 1	,		//automatic receive data then transmit data 
	parameter AUTO_RNUM	= 8	,		
	parameter AUTO_WNUM	= 8	,
	parameter TS_NUM	= 4				// setup time loop number 
)
(
	/* FPGA main interface */
	input						clk			,
	input						rst_n			,
	/* USB FIFO Indication*/
	input						usb_n_ept_to,	/*FIFO2 empty*/
	input						usb_n_ept_fr,	/*FIFO4 empty*/
	input						usb_n_ful_sx,	/*FIFO6 full */
	inout	[15:0]			usb_data		,
	/* device ctrl */
	input	[10:0]			rd_wr_num	,	/* the number of read or write data  */	
	input	[ 1:0]			rd_wr_en		,  /* 10 -> read or 01 -> write */
	output					usb_is_busy	,  
	output	reg	[15:0]read_data	,
	input	[15:0]			write_data	,
	output	reg			output_valid,
	output	reg			write_ready	,
	/* USB Ctrl Signal*/
	output	reg			usb_slcs		,	/* chipselect */
	output	reg			usb_sloe		,	/* data output enable */
	output	reg			usb_slrd		,	/* read indicate */
	output	reg			usb_slwr		,	/* write req */
	output	reg	[ 1:0]usb_addr		
);

//FSM State
localparam	IDLE = 4'd0		,
				RD_PRE=4'd1		,
				RD = 4'd2		,
				RD_BURST = 4'd3,
				RD_OVER = 4'd5	,
				WR = 4'd7		,
				WR_BURST = 4'd9,
				WR_OVER = 4'd11
				;
//read_date
wire	[15:0]	rec_data	;
//FSM register
reg	[ 3:0]	state		;
reg	[ 3:0]	state_nxt;
//indication whether to write or read
reg				wr_req	;
//the counter of setup time 
reg	[ 7:0]	ts_cnt	;

reg	[15:0]	tra_data	;
// the counter of write data or read data 
reg	[10:0]	cnt_data	;


/* only LOOP_WORK set to 1, the receive data will be sent to PC again */
assign	usb_data = wr_req ? ((LOOP_WORK == 1) ? rec_data : tra_data) : 16'hzzzz;
assign	rec_data =	read_data;
//when state != IDLe and need to read but fifo is emptyed or need to write but fifo is full, is_busy will be high
assign	usb_is_busy = (state == IDLE) ? 1'b0 : ((rd_wr_en == 2'b10 && !usb_n_ept_to) ? 1'b0 : ((rd_wr_en == 2'b01 && !usb_n_ful_sx) ? 1'b0: 1'b1)); 

always @ (posedge clk or negedge rst_n)
begin
	if (!rst_n)
	begin
		state	<=	IDLE;
	end
	else
	begin
		state	<=	state_nxt;
	end
end

/*
FSM
AUTOWORK == 1	// Test Mode
IDLE				RD											RD_BURST			WR											WR_BURST
FIFO2 not empty	->	the number of read data meet AUTO_RNUM	->	FIFO6 not full ->	the number of write data meet AUTO_RNUM ->   IDLE

AUTOWORK == 1												->	RD_OVER(RD)  -----|
IDLE				RD										|	RD_BURST		  |
FIFO2 not empty	->	the number of read data meet rd_wr_num	->	IDLE		<------
and FIFO6 not 												->	WR_OVER(WR)	------|
full and			WR										|	WR_BURST		  |
case(rd_wr_en)	->	the number of write data meet rd_wr_num	->	IDLE		<------
*/
always @ (*)
begin
	state_nxt = state;
	case (state)
	IDLE:
	begin
		if (AUTO_WORK == 0)
			case (rd_wr_en)
			2'b10: state_nxt = usb_n_ept_to ? RD_PRE : IDLE;
			2'b01: state_nxt = usb_n_ful_sx ? WR : IDLE;
			default: state_nxt = IDLE;
			endcase
		else
			state_nxt	=	usb_n_ept_to ? RD : (usb_n_ful_sx ? WR : IDLE);
	end
	
	RD_PRE:
	begin
		state_nxt	=	RD;
	end
	
	RD:
	begin
		if (!usb_n_ept_to) 
			state_nxt	=	RD_BURST;
		else if (AUTO_WORK == 0)
			if (rd_wr_en == 2'b10 && cnt_data >= rd_wr_num)
				state_nxt	=	RD_OVER;
			else if (cnt_data >= rd_wr_num)
				state_nxt 	=	RD_BURST;
			else
				state_nxt	=	RD;
		else
			if (cnt_data >= AUTO_RNUM)
				state_nxt	=	RD_BURST;
			else
				state_nxt	=	RD;
	end

	RD_BURST:
	begin
		if (AUTO_WORK == 0)
			state_nxt	=	IDLE;
		else
			state_nxt	=	usb_n_ful_sx ? WR : IDLE;
	end

	RD_OVER:
	begin
		if (!usb_n_ept_to) 
			state_nxt	=	RD_BURST;
		else if (rd_wr_en == 2'b10 && cnt_data >= rd_wr_num)
			state_nxt	=	RD_OVER;
		else if (cnt_data >= rd_wr_num)
			state_nxt 	=	RD_BURST;
	end

	WR:
	begin
		if (!usb_n_ful_sx) 
			state_nxt	=	WR_BURST;
		else if (AUTO_WORK == 0)
			if (rd_wr_en == 2'b01 && cnt_data >= rd_wr_num - 11'd1)
				state_nxt	=	WR_OVER;
			else if (cnt_data >= rd_wr_num - 11'd1)
				state_nxt 	=	WR_BURST;
			else
				state_nxt	=	WR;
		else
			if (cnt_data >= AUTO_RNUM - 1)
				state_nxt	=	WR_BURST;
			else
				state_nxt	=	WR;
	end

	WR_BURST:	state_nxt	=	IDLE	;

	WR_OVER:
	begin
		if (!usb_n_ful_sx) 
			state_nxt	=	WR_BURST;
		else if (rd_wr_en == 2'b01 && cnt_data >= rd_wr_num - 11'd1)
			state_nxt	=	WR_OVER;
		else if (cnt_data >= rd_wr_num - 11'd1)
			state_nxt 	=	WR_BURST;
	end
	default:state_nxt	=	state;
	endcase
end


// internal signal
always @ (posedge clk or negedge rst_n)
begin
	if (!rst_n) 
	begin
		wr_req	<=	'd0;
		cnt_data	<=	'd0;
		ts_cnt	<=	'd0;
	end
	else
	case (state)
	IDLE:
	begin
		cnt_data	<=	'd0;
		wr_req	<=	'd0;
		if (state_nxt == RD)
		begin
			ts_cnt<=	'd0;
			wr_req<=  'd0;
		end
		else if (state_nxt == WR)
		begin
			wr_req<= 1'b1;
		end
	end
	
	RD_PRE: ;
	/*
	RD_OVER -> cnt_data need to be reset
	*/
	RD, WR:
	begin
		if (state_nxt == RD_OVER || state_nxt == WR_OVER)
		begin
			cnt_data	<=	'd0;
			ts_cnt	<=	'd0;
		end
		else if (ts_cnt >= TS_NUM - 1)
		begin
			cnt_data	<= cnt_data + 11'd1;
			ts_cnt 	<=	'd0;
		end
		else 
		begin
			ts_cnt	<=	ts_cnt + 8'd1;
		end
	end

	RD_BURST, WR_BURST:
	begin
		cnt_data	<=	'd0	;
		ts_cnt	<=	'd0;
	end
	/*WR_OVER and RD_OVER is only exist when AUTO_WOOK == 0*/
	RD_OVER, WR_OVER:
	begin
		if ((state_nxt == RD_OVER || state_nxt == WR_OVER) && cnt_data > rd_wr_num - 1)
			cnt_data <=	'd0;
		else if (ts_cnt >= TS_NUM - 1)
		begin
			cnt_data	<= cnt_data + 11'd1;
			ts_cnt 	<=	'd0;
		end
		else 
		begin
			ts_cnt	<=	ts_cnt + 8'd1;
		end
	end
	default:;
	endcase
end

//external signal
always @ (posedge clk or negedge rst_n)
begin
	if (!rst_n) 
	begin
		tra_data<=	'd0;
		usb_slcs<=	'd0;
		usb_sloe<=	1'b1;
		usb_slrd<=	1'b1;
		usb_slwr<=	1'b1;
		usb_addr<=	'd0;
		read_data<=	'd0;
		output_valid<='d0;
		write_ready<='d0;
	end
	else
	case (state)
	IDLE:
	begin
		usb_slcs<=	'd0;
		output_valid<='d0;
		write_ready<='d0;
		usb_sloe<=	1'b1;
		usb_slrd<=	1'b1;
		usb_slwr<=	1'b1;
		if (state_nxt == RD)
		begin
			usb_addr	<= 2'b0;
			usb_sloe	<= 1'b1;
			usb_slrd	<= 1'b1;
		end
		else if (state_nxt == WR)
		begin
			usb_addr	<= 2'b10;
			usb_slwr	<= 1'b1;
		end
	end
	
	RD_PRE:
	begin
		usb_sloe	<=	1'b0;
		usb_slrd	<=	1'b0;
	end
		
	/*
	RD_OVER -> cnt_data need to be reset
	*/
	RD, RD_OVER:
	begin
		if (ts_cnt >= TS_NUM - 1)
		begin
			usb_sloe	<=	1'b0;
			usb_slrd	<=	1'b0;
			read_data 	<=	usb_data;	
			output_valid<=	1'b1;
		end
		else 
		begin
			usb_sloe	<=	1'b1;
			usb_slrd	<=	1'b1;
			
			output_valid<=	1'b0;
		end
	end
	/*WR_OVER and RD_OVER is only exist when AUTO_WOOK == 0*/
	RD_BURST, WR_BURST:
	begin
		output_valid<=	1'b0;
		read_data<=	usb_data;	
		usb_sloe	<=	1'b1;
		usb_slrd	<=	1'b1;
		if (state_nxt == WR)
		   usb_addr <= 2'b10;
			
		tra_data	<=	write_data;	
		write_ready	<=	1'b0;
		usb_slwr	<=	1'b1;
	end
	
	/* cas time == TS_NUM clk*/
	WR, WR_OVER:
	begin
		if (ts_cnt >= TS_NUM - 1 )
		begin
			usb_slwr	<=	1'b0;
			write_ready	<=	1'b1;
			tra_data	<= 	read_data;
			read_data<=		read_data + 16'd1;
		end
		else
		begin
			usb_slwr		<=	1'b1;
		end		
	end
	default:usb_slcs <= 1'b1;
	endcase
end

endmodule 
