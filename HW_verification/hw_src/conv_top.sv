/////////////////////////////////////////////////////////////////////
//
// Title: conv_top.sv
// Author: Seongmin Hong
//
/////////////////////////////////////////////////////////////////////
/*
`timescale 1 ns / 1 ps

module conv_top #(
  parameter IF_WIDTH     = 128,
  parameter IF_HEIGHT    = 128,
  parameter IF_CHANNEL   = 3,
  parameter IF_BITWIDTH  = 16,
  parameter IF_FRAC_BIT  = 8,
  parameter IF_PORT      = 27,

  parameter K_WIDTH      = 3,
  parameter K_HEIGHT     = 3,
  parameter K_CHANNEL    = 3,
  parameter K_BITWIDTH   = 8,
  parameter K_FRAC_BIT   = 6,
  parameter K_PORT       = 1,
  parameter K_NUM        = 3,

  parameter OF_WIDTH     = 128,
  parameter OF_HEIGHT    = 128,
  parameter OF_CHANNEL   = 3,
  parameter OF_BITWIDTH  = 16,
  parameter OF_FRAC_BIT  = 8,
  parameter OF_PORT      = 1,
  parameter OF_NUM       = 3
)
(
  input  logic                                             clk,
  input  logic                                             rst,

  input  logic                                             if_start,
  input  logic                                             k_prefetch,
  output logic                                             of_done,

  input  logic [IF_PORT-1:0][IF_BITWIDTH-1:0]              if_i_data,
  input  logic [IF_PORT-1:0]                               if_i_valid,
  input  logic [K_NUM-1:0][K_PORT-1:0][K_BITWIDTH-1:0]     k_i_data,
  input  logic [K_NUM-1:0][K_PORT-1:0]                     k_i_valid,
  output logic [OF_NUM-1:0][OF_PORT-1:0][OF_BITWIDTH-1:0]  of_o_data,
  output logic [OF_NUM-1:0][OF_PORT-1:0]                   of_o_valid
);

/////////////////////////////////////////////////////////////////////

localparam A_BITWIDTH  = IF_BITWIDTH;      //16
localparam A_FRAC_BIT  = IF_FRAC_BIT;      //8
localparam W_BITWIDTH  = K_BITWIDTH;       //8
localparam W_FRAC_BIT  = K_FRAC_BIT;       //6
localparam P_BITWIDTH  = A_BITWIDTH*2 + W_BITWIDTH;   
localparam P_FRAC_BIT  = A_FRAC_BIT + W_FRAC_BIT;     //14

/////////////////////////////////////////////////////////////////////

logic [IF_PORT-1:0][K_NUM-1:0]                            prefetch_in;
logic [IF_PORT-1:0][K_NUM-1:0]                            prefetch_out;

logic signed [IF_PORT-1:0][K_NUM-1:0][A_BITWIDTH-1:0]            a_data_in;
logic [IF_PORT-1:0][K_NUM-1:0]                            a_valid_in;
logic signed [IF_PORT-1:0][K_NUM-1:0][A_BITWIDTH-1:0]            a_data_out;
logic [IF_PORT-1:0][K_NUM-1:0]                            a_valid_out;

logic signed [IF_PORT-1:0][K_NUM-1:0][W_BITWIDTH-1:0]            w_data_in;
logic [IF_PORT-1:0][K_NUM-1:0]                            w_valid_in;
logic signed [IF_PORT-1:0][K_NUM-1:0][W_BITWIDTH-1:0]            w_data_out;
logic [IF_PORT-1:0][K_NUM-1:0]                            w_valid_out;

logic signed [IF_PORT-1:0][K_NUM-1:0][P_BITWIDTH-1:0]            p_data_in;
logic [IF_PORT-1:0][K_NUM-1:0]                            p_valid_in;
logic signed [IF_PORT-1:0][K_NUM-1:0][P_BITWIDTH-1:0]            p_data_out;
logic [IF_PORT-1:0][K_NUM-1:0]                            p_valid_out;

logic [$clog2(IF_WIDTH*IF_HEIGHT):0]                      of_data_cnt;

genvar i, j, k;
generate 
  for ( i=0; i<IF_PORT; i=i+1) begin: loop_mac_i
    for (j=0; j<K_NUM; j=j+1) begin: loop_mac_j

    MAC #(
      .A_BITWIDTH     ( A_BITWIDTH            ),
      .W_BITWIDTH     ( W_BITWIDTH            ),
      .P_BITWIDTH     ( P_BITWIDTH            ),
      .ROW_NUM        ( IF_PORT               ),
      .ROW_INDEX      ( i                     )
    )
    u_MAC_unit(
      .clk                                                (clk),
      .rst                                                (rst),

      .prefetch_in                                        (prefetch_in[i][j]),
      .prefetch_out                                       (prefetch_out[i][j]),

      .a_data_in                                          (a_data_in[i][j]),
      .a_valid_in                                         (a_valid_in[i][j]),
      .a_data_out                                         (a_data_out[i][j]),
      .a_valid_out                                        (a_valid_out[i][j]),

      .w_data_in                                          (w_data_in[i][j]),
      .w_valid_in                                         (w_valid_in[i][j]),
      .w_data_out                                         (w_data_out[i][j]),
      .w_valid_out                                        (w_valid_out[i][j]),

      .p_data_in                                          (p_data_in[i][j]),
      .p_valid_in                                         (p_valid_in[i][j]),
      .p_data_out                                         (p_data_out[i][j]),
      .p_valid_out                                        (p_valid_out[i][j])
    );

    if (j==0) begin
      assign a_data_in[i][j]                              = if_i_data[i];
      assign a_valid_in[i][j]                             = if_i_valid[i];       
    end
    else begin
      assign a_data_in[i][j]                              = a_data_out[i][j-1];
      assign a_valid_in[i][j]                             = a_valid_out[i][j-1];
    end

    if (i==0) begin
      assign w_data_in[i][j]                              = k_i_data[j];
      assign w_valid_in[i][j]                             = k_i_valid[j];
      assign prefetch_in[i][j]                            = k_prefetch;
    end
    else begin
      assign w_data_in[i][j]                              = w_data_out[i-1][j];
      assign w_valid_in[i][j]                             = w_valid_out[i-1][j];
      assign prefetch_in[i][j]                            = prefetch_out[i-1][j];
    end

    if (i==0) begin
      assign p_data_in[i][j]                              = 0;
      assign p_valid_in[i][j]                             = 0;
    end
    else begin
      assign p_data_in[i][j]                              = p_data_out[i-1][j];
      assign p_valid_in[i][j]                             = p_valid_out[i-1][j];
    end
    end
  end
  for (k=0; k<K_NUM; k=k+1) begin : loop_mac_k
    always_ff @(posedge clk) begin
      if (rst) begin
        of_o_data[k]                                      <= 0;
        of_o_valid[k]                                     <= 0;
      end
      else begin
        of_o_data[k]                                      <= p_data_out[IF_PORT-1][k][P_FRAC_BIT-OF_FRAC_BIT +: OF_BITWIDTH];
        of_o_valid[k]                                     <= p_valid_out[IF_PORT-1][k];
      end

    end
  end
endgenerate

always_ff @(posedge clk) begin
  if (rst) begin
    of_data_cnt                                           <= 0;
  end
  else if (if_start) begin
    of_data_cnt                                           <= 0;
  end
  else if (of_o_valid[K_NUM-1]) begin
    of_data_cnt                                           <= of_data_cnt + 1;
  end
end

//of_done
always_ff @(posedge clk) begin
  if (rst) begin
    of_done                                               <= 0;
  end
  else if (of_o_valid[K_NUM-1] && of_data_cnt == IF_WIDTH*IF_HEIGHT-1) begin
    of_done                                               <= 1;
  end
  else begin
    of_done                                               <= 0;
  end
end
endmodule
*/


`timescale 1 ns / 1 ps

module conv_top #(
  parameter IF_WIDTH     = 128,
  parameter IF_HEIGHT    = 128,
  parameter IF_CHANNEL   = 3,
  parameter IF_BITWIDTH  = 16,
  parameter IF_FRAC_BIT  = 8,
  parameter IF_PORT      = 27,

  parameter K_WIDTH      = 3,
  parameter K_HEIGHT     = 3,
  parameter K_CHANNEL    = 3,
  parameter K_BITWIDTH   = 8,
  parameter K_FRAC_BIT   = 6,
  parameter K_PORT       = 1,
  parameter K_NUM        = 3,

  parameter OF_WIDTH     = 128,
  parameter OF_HEIGHT    = 128,
  parameter OF_CHANNEL   = 3,
  parameter OF_BITWIDTH  = 16,
  parameter OF_FRAC_BIT  = 8,
  parameter OF_PORT      = 1,
  parameter OF_NUM       = 3
)
(
  input  logic                                             clk,
  input  logic                                             rst,

  input  logic                                             if_start,
  input  logic                                             k_prefetch,
  output logic                                             of_done,

  input  logic [IF_PORT-1:0][IF_BITWIDTH-1:0]              if_i_data,
  input  logic [IF_PORT-1:0]                               if_i_valid,
  input  logic [K_NUM-1:0][K_PORT-1:0][K_BITWIDTH-1:0]     k_i_data,
  input  logic [K_NUM-1:0][K_PORT-1:0]                     k_i_valid,
  output logic [OF_NUM-1:0][OF_PORT-1:0][OF_BITWIDTH-1:0]  of_o_data,
  output logic [OF_NUM-1:0][OF_PORT-1:0]                   of_o_valid
);

/////////////////////////////////////////////////////////////////////

localparam A_BITWIDTH  = IF_BITWIDTH;      //16
localparam A_FRAC_BIT  = IF_FRAC_BIT;      //8
localparam W_BITWIDTH  = K_BITWIDTH;       //8
localparam W_FRAC_BIT  = K_FRAC_BIT;       //6
localparam P_BITWIDTH  = A_BITWIDTH*2 + W_BITWIDTH;   
localparam P_FRAC_BIT  = A_FRAC_BIT + W_FRAC_BIT;     //14

/////////////////////////////////////////////////////////////////////
///logic [OF_NUM-1:0][OF_PORT-1:0][OF_BITWIDTH-1:0]  of_o_data;
logic [IF_PORT-1:0][K_NUM-1:0]                            prefetch_in;
logic [IF_PORT-1:0][K_NUM-1:0]                            prefetch_out;

logic signed [IF_PORT-1:0][K_NUM-1:0][A_BITWIDTH-1:0]            a_data_in;
logic [IF_PORT-1:0][K_NUM-1:0]                            a_valid_in;
logic signed [IF_PORT-1:0][K_NUM-1:0][A_BITWIDTH-1:0]            a_data_out;
logic [IF_PORT-1:0][K_NUM-1:0]                            a_valid_out;

logic signed [IF_PORT-1:0][K_NUM-1:0][W_BITWIDTH-1:0]            w_data_in;
logic [IF_PORT-1:0][K_NUM-1:0]                            w_valid_in;
logic signed [IF_PORT-1:0][K_NUM-1:0][W_BITWIDTH-1:0]            w_data_out;
logic [IF_PORT-1:0][K_NUM-1:0]                            w_valid_out;

logic signed [IF_PORT-1:0][K_NUM-1:0][P_BITWIDTH-1:0]            p_data_in;
logic [IF_PORT-1:0][K_NUM-1:0]                            p_valid_in;
logic signed [IF_PORT-1:0][K_NUM-1:0][P_BITWIDTH-1:0]            p_data_out;
logic [IF_PORT-1:0][K_NUM-1:0]                            p_valid_out;

logic [$clog2(IF_WIDTH*IF_HEIGHT):0]                      of_data_cnt;

logic signed [IF_PORT-1:0][K_NUM-1:0]         z_sig_in;
logic signed [IF_PORT-1:0][K_NUM-1:0]         z_sig_out;

/*
always_ff @(posedge clk) begin
  if(rst)begin
    of_o_data_prime <= 0;
  end
  else begin
    of_o_data_prime <= of_o_data;
 end
  end
  */
genvar i, j, k;
generate 
  for ( i=0; i<IF_PORT; i=i+1) begin: loop_mac_i
    for (j=0; j<K_NUM; j=j+1) begin: loop_mac_j

    MAC #(
      .A_BITWIDTH     ( A_BITWIDTH            ),
      .W_BITWIDTH     ( W_BITWIDTH            ),
      .P_BITWIDTH     ( P_BITWIDTH            ),
      .ROW_NUM        ( IF_PORT               ),
      .ROW_INDEX      ( i                     )
    )
    u_MAC_unit(
      .clk                                                (clk),
      .rst                                                (rst),

      .prefetch_in                                        (prefetch_in[i][j]),
      .prefetch_out                                       (prefetch_out[i][j]),

      .a_data_in                                          (a_data_in[i][j]),
      .a_valid_in                                         (a_valid_in[i][j]),
      .a_data_out                                         (a_data_out[i][j]),
      .a_valid_out                                        (a_valid_out[i][j]),

      .w_data_in                                          (w_data_in[i][j]),
      .w_valid_in                                         (w_valid_in[i][j]),
      .w_data_out                                         (w_data_out[i][j]),
      .w_valid_out                                        (w_valid_out[i][j]),

      .p_data_in                                          (p_data_in[i][j]),
      .p_valid_in                                         (p_valid_in[i][j]),
      .p_data_out                                         (p_data_out[i][j]),
      .p_valid_out                                        (p_valid_out[i][j]),
      .z_sig_in                                            (     z_sig_in[i][j]         ),
      .z_sig_out                                          (      z_sig_out[i][j]          )
    );

    if (j==0) begin
      assign a_data_in[i][j]                              = if_i_data[i];
      assign a_valid_in[i][j]                             = if_i_valid[i];       
    end
    else begin
      assign a_data_in[i][j]                              = a_data_out[i][j-1];
      assign a_valid_in[i][j]                             = a_valid_out[i][j-1];
    end

    if (i==0) begin
      assign w_data_in[i][j]                              = k_i_data[j];
      assign w_valid_in[i][j]                             = k_i_valid[j];
      assign prefetch_in[i][j]                            = k_prefetch;
    end
    else begin
      assign w_data_in[i][j]                              = w_data_out[i-1][j];
      assign w_valid_in[i][j]                             = w_valid_out[i-1][j];
      assign prefetch_in[i][j]                            = prefetch_out[i-1][j];
    end

    if (i==0) begin
      assign p_data_in[i][j]                              = 0;
      assign p_valid_in[i][j]                             = 0;
    end
    else begin
      assign p_data_in[i][j]                              = p_data_out[i-1][j];
      assign p_valid_in[i][j]                             = p_valid_out[i-1][j];
    end
    end
  end
  for (k=0; k<K_NUM; k=k+1) begin : loop_mac_k
    always_ff @(posedge clk) begin
      if (rst) begin
        of_o_data[k]                                      <= 0;
        of_o_valid[k]                                     <= 0;
      end
      else begin
        of_o_data[k]                                      <= p_data_out[IF_PORT-1][k][P_FRAC_BIT-OF_FRAC_BIT +: OF_BITWIDTH];
        of_o_valid[k]                                     <= p_valid_out[IF_PORT-1][k];
      end

    end
  end
endgenerate

always_ff @(posedge clk) begin
  if (rst) begin
    of_data_cnt                                           <= 0;
  end
  else if (if_start) begin
    of_data_cnt                                           <= 0;
  end
  else if (of_o_valid[K_NUM-1]) begin
    of_data_cnt                                           <= of_data_cnt + 1;
  end
end

//of_done
always_ff @(posedge clk) begin
  if (rst) begin
    of_done                                               <= 0;
  end
  else if (of_o_valid[K_NUM-1] && of_data_cnt == IF_WIDTH*IF_HEIGHT-1) begin
    of_done                                               <= 1;
  end
  else begin
    of_done                                               <= 0;
  end
end
endmodule
