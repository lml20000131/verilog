module tx#(
    parameter CHECK_MODE = 1,  //1--odd,0---even
    parameter BAUD_NUM = 50_000_000/115200  //baud rate,receive or transfer 1 bit data need 434 clk period
)(
    input                       clk             ,  //50MHz--20ns
    input                       rstn            ,

    input                       tx_data_valid   ,
    input  [7:0]                tx_data         ,
    
    output                      tx              ,  // serial data
    output                      tx_done            //to master finish and can accept next data
);

localparam IDLE  = 3'd0;
localparam START = 3'd1;
localparam DATA  = 3'd2;
localparam CHECK = 3'd3;
localparam STOP  = 3'd4;

reg [2:0] cur_state, nxt_state;

//------baud_cnt---------
reg [8:0] baud_cnt_r;
wire      baud_cnt_end;

always @(posedge clk or negedge rstn)begin
    if(!rstn)
        baud_cnt_r <= 'b0;
    else if(cur_state == IDLE)
        baud_cnt_r <= 'b0;
    else if(baud_cnt_end)
        baud_cnt_r <= 'b0;
    else 
        baud_cnt_r <= baud_cnt_r + 1;
end

assign baud_cnt_end = baud_cnt_r == BAUD_NUM - 1;
//--------------------------------------------


//------bit_cnt---------
reg [2:0] bit_cnt_r;

always @(posedge clk or negedge rstn)begin
    if(!rstn)
        bit_cnt_r <= 'b0;
    else if(cur_state == DATA)
            if(baud_cnt_end)
                bit_cnt_r <= bit_cnt_r + 3'd1;
    else 
        bit_cnt_r <= 'b0;  
end
//--------------------------------------


//------tx_data-----------
reg [7:0] tx_data_r;

always @(posedge clk or negedge rstn)begin
    if(!rstn)
        tx_data_r <= 'b0;
    else if(tx_data_valid)
        tx_data_r <= tx_data;
end
//--------------------------------


//------FSM-------------
always @(posedge clk or negedge rstn)begin
    if(!rstn)
        cur_state <= IDLE;
    else 
        cur_state <= nxt_state;
end

always @(*)begin
    case(cur_state)
        IDLE  : nxt_state = tx_data_valid ? START : IDLE;
        START : nxt_state = baud_cnt_end ? DATA : START;
        DATA  : nxt_state = (bit_cnt_r == 7 && baud_cnt_end) ? CHECK : DATA;
        CHECK : nxt_state = (baud_cnt_end) ? STOP : CHECK;
        STOP  : nxt_state = baud_cnt_end ? IDLE : STOP;
        default : nxt_state = IDLE;
    endcase
end
//------------------------------------------------------


//-------tx------------
reg tx_r; 
always @(posedge clk or negedge rstn)begin
    if(!rstn)
        tx_r <= 1'b1;
    else case(cur_state)
        IDLE  : tx_r <= 1'b1;
        START : tx_r <= 1'b0;
        DATA  : tx_r <= tx_data_r[bit_cnt_r];
        CHECK : tx_r <= ^{tx_data_r,CHECK_MODE};
        default tx_r <= 1'b1;
    endcase
end
//----------------------------------------


//-----tx_done--------------
reg tx_done_r;
always @(posedge clk or negedge rstn)begin
    if(!rstn)
        tx_done_r <= 1'b0;
    else if(cur_state == STOP && baud_cnt_end)
        tx_done_r <= 1'b1;
    else 
        tx_done_r <= 1'b0;
end
//----------------------------------------------------

endmodule
