`timescale 1 ns / 1 ps


module MAC 
#(
parameter A_BITWIDTH                        = 16,
parameter W_BITWIDTH                        = 8,
parameter P_BITWIDTH                        = 40,
parameter M_BITWIDTH                        = 24,
parameter ROW_NUM                           = 27,
parameter ROW_INDEX                         = 0
)
(
input  logic                                clk,
input  logic                                rst,
input  logic                                prefetch_in,
output logic                                prefetch_out,

input  logic signed [A_BITWIDTH-1:0]        a_data_in,
input  logic                                a_valid_in,
output logic signed [A_BITWIDTH-1:0]        a_data_out,
output logic                                a_valid_out,

input  logic signed [W_BITWIDTH-1:0]        w_data_in,
input  logic                                w_valid_in,
output logic signed [W_BITWIDTH-1:0]        w_data_out,
output logic                                w_valid_out,

input  logic signed [P_BITWIDTH-1:0]        p_data_in,
input  logic                                p_valid_in,
output logic signed [P_BITWIDTH-1:0]        p_data_out,
output logic                                p_valid_out,
input logic z_sig_in,
output logic z_sig_out
);


logic signed [W_BITWIDTH-1:0]               w_fetch_data, w_fetch_data_nxt;
logic [5:0]                                 w_fetch_cnt;

logic signed [M_BITWIDTH-1:0]               mul_data;
logic                                       mul_valid;

logic signed [P_BITWIDTH-1:0]               add_data;
logic                                       add_valid;

logic signed [A_BITWIDTH-1:0]               a_data_in_ff;
logic                                       a_valid_in_ff;

always_comb begin
    if(w_data_in ==0 | a_data_in == 0) begin
    z_sig_out =1;
    end
    else begin
    z_sig_out =0;
    end
end

//w_fetch_cnt
always_ff @(posedge clk) begin
    if (rst) begin
        w_fetch_cnt                         <= 0;
    end
    else if (prefetch_in) begin
        w_fetch_cnt                         <= 0;
    end
    else if (w_valid_in && w_fetch_cnt == (ROW_NUM - 1)) begin
        w_fetch_cnt                         <= 0;
    end
    else if (w_valid_in && w_fetch_cnt != (ROW_NUM - 1)) begin
        w_fetch_cnt                         <= w_fetch_cnt + 1;
    end

end
//prefetch
always_ff @(posedge clk) begin
    if (rst) begin
        prefetch_out                        <= 0;
    end
    else begin
        prefetch_out                        <= prefetch_in;
    end
end

//w_valid_out
always_ff @(posedge clk) begin
    if (rst) begin
        w_valid_out                         <= 1'b0;
    end
    else begin
        w_valid_out                         <= w_valid_in;
    end
end

//w_data_out
always_ff @(posedge clk) begin
    if (rst) begin
        w_data_out                          <= 0;
    end
    else begin
        w_data_out                          <= w_data_in;
    end
end

//w_fetch_data
always_ff @(posedge clk) begin
    if (rst) begin
        w_fetch_data                        <= 0;
    end
    else begin
        w_fetch_data                        <= w_fetch_data_nxt;
    end
end

always_comb begin
    w_fetch_data_nxt                        = w_fetch_data;
    if (w_valid_in && w_fetch_cnt == ROW_NUM - ROW_INDEX - 1) begin
        w_fetch_data_nxt                    = w_data_in;
    end
end

//a_ff
always_ff @(posedge clk) begin
    if (rst) begin
        a_data_in_ff                        <= 0;
        a_valid_in_ff                       <= 0;
    end
    else begin
        a_data_in_ff                        <= a_data_in;
        a_valid_in_ff                       <= a_valid_in;
    end 
end

// a_out
always_comb begin
    a_data_out                              = a_data_in_ff;
    a_valid_out                             = a_valid_in_ff;
end

//mul

always_comb begin
    if(z_sig_in == 1) begin
        mul_data = 0;
    end
    else begin
        mul_data = a_data_in_ff * w_fetch_data;
    end
end

assign mul_valid                            = a_valid_in_ff;

//add

always_comb begin
    if (ROW_INDEX == 0) begin
        add_data                            = mul_data;
    end
    else begin
        add_data                            = mul_data + p_data_in;
    end
end

//p_data_out

always_ff @(posedge clk) begin
    if (rst) begin
        p_data_out                          <= 0;
    end
    else begin
        // if (add_data[P_BITWIDTH:P_BITWIDTH-1] == 2'b01) begin
        //     p_data_out                      <= {1'b0,(P_BITWIDTH-1){1'b1}};
        // end
        // else if(add_data[P_BITWIDTH:P_BITWIDTH-1] == 2'b10) begin
        //     p_data_out                      <= {1'b1,(P_BITWIDTH-1){1'b0}};
        // end
        // else begin
        //     p_data_out                      <= add_data;
        // end
        p_data_out                          <= add_data;
    end
end 

//add_valid
always_comb begin
    if (ROW_INDEX == 0) begin
        add_valid                           = mul_valid; 
    end
    else begin
        add_valid                           = mul_valid & p_valid_in;
    end
end

//p_valid_out
always_ff @(posedge clk) begin
    if (rst) begin
        p_valid_out                         <= 0;
    end
    else begin
        p_valid_out                         <= add_valid;
    end
end
endmodule