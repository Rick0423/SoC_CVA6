// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Paul Scheffler <paulsc@iis.ee.ethz.ch>
// Armin Berger <bergerar@ethz.ch>
// Stephan Keck <kecks@ethz.ch>

module hyperbus_trx #(
    parameter int unsigned IsClockODelayed = -1,
    parameter int unsigned NumChips        = 2,
    parameter int unsigned RxFifoLogDepth  = 3,
    parameter int unsigned SyncStages      = 2
)(
    // Global signals
    input  logic                   clk_i,
    input  logic                   clk_i_90,
    input  logic                   rst_ni,
    input  logic                   test_mode_i,

    input  logic [3:0]             cfg_edge_idx_i,
    input  logic                   cfg_edge_pol_i,

    // Transciever control: facing controller
    input  logic [NumChips-1:0]    cs_i,
    input  logic                   cs_ena_i,
    output logic                   rwds_sample_o,
    input  logic                   rwds_sample_ena_i,

    input  logic [3:0]             tx_clk_delay_i,
    input  logic                   tx_clk_ena_i,
    input  logic [15:0]            tx_data_i,
    input  logic                   tx_data_oe_i,
    input  logic [1:0]             tx_rwds_i,
    input  logic                   tx_rwds_oe_i,

    input  logic [1:0]             rx_clk_delay_i,
    input  logic                   rx_clk_set_i,
    input  logic                   rx_clk_reset_i,
    output logic [15:0]            rx_data_o,
    output logic                   rx_valid_o,
    input  logic                   rx_ready_i,
    // Physical interface: facing HyperBus
    output logic [NumChips-1:0]    hyper_cs_no,
    output logic                   hyper_ck_o,
    output logic                   hyper_ck_no,
    output logic                   hyper_rwds_o,
    input  logic                   hyper_rwds_i,
    output logic                   hyper_rwds_oe_o,
    input  logic [7:0]             hyper_dq_i,
    output logic [7:0]             hyper_dq_o,
    output logic                   hyper_dq_oe_o,
    output logic                   hyper_reset_no
);

    // 90-degree-shifted clocks
    logic tx_clk_ena_q;
    logic tx_clk_90;
    logic rx_rwds_90;

    // Intermediate RX signals for RWDS domain
    logic           rx_rwds_clk_ena;
    logic           rx_rwds_clk;
    logic           rx_rwds_soft_rst;
    logic [15:0]    rx_rwds_fifo_in;
    logic           rx_rwds_fifo_valid;
    logic           rx_rwds_fifo_ready;

    // Feed through async reset
    assign hyper_reset_no = rst_ni;

    // =================
    //    TX + control
    // =================

    // Shift clock by 90 degrees
    assign tx_clk_90 = clk_i_90;

    // 90deg-shifted differential output clock, sampling output bytes centrally
    hyperbus_clock_diff_out i_clock_diff_out (
        .in_i   ( tx_clk_90     ),
        .en_i   ( tx_clk_ena_q  ),
        .out_o  ( hyper_ck_o    ),
        .out_no ( hyper_ck_no   )
    );

    // Synchronize output chip select to shifted differential output clock
    always_ff @(posedge tx_clk_90 or negedge rst_ni) begin : proc_ff_tx_shift90
        if (~rst_ni)    hyper_cs_no <= '1;
        else            hyper_cs_no <= cs_ena_i ? ~cs_i : '1;
    end

    // Data output DDR converters
    for (genvar i = 0; i <= 7; i++) begin: gen_ddr_tx_data
        hyperbus_ddr_out #(
            .Init   ( 1'b0 )
        ) i_ddr_tx_data (
            .clk_i  ( clk_i             ),
            .rst_ni ( rst_ni            ),
            .d0_i   ( tx_data_i  [i+8]  ),
            .d1_i   ( tx_data_i  [i]    ),
            .q_o    ( hyper_dq_o [i]    )
        );
    end

    // RWDS output DDR converter
    hyperbus_ddr_out #(
        .Init   ( 1'b0 )
    ) i_ddr_tx_rwds (
        .clk_i  ( clk_i         ),
        .rst_ni ( rst_ni        ),
        .d0_i   ( tx_rwds_i [1] ),
        .d1_i   ( tx_rwds_i [0] ),
        .q_o    ( hyper_rwds_o  )
    );

    // Delay output, clock enables to be synchronous with DDR-converted data
    // The delayed clock also ensures t_CSS is respected at the start, end of CS
    always_ff @(posedge clk_i or negedge rst_ni) begin : proc_ff_tx_delay
        if(~rst_ni) begin
            hyper_rwds_oe_o <= 1'b0;
            hyper_dq_oe_o   <= 1'b0;
            tx_clk_ena_q    <= 1'b0;
        end else begin
            hyper_rwds_oe_o <= tx_rwds_oe_i;
            hyper_dq_oe_o   <= tx_data_oe_i;
            tx_clk_ena_q    <= tx_clk_ena_i;
        end
    end

    // ========
    //    RX
    // ========

    // sample RWDS for extra latency determination (adjustable sampling edge)
    hyperbus_rwds_sampler i_rwds_sampler (
        .clk_i,
        .rst_ni,
        .test_mode_i,
        .cfg_edge_idx_i,
        .cfg_edge_pol_i,
        .rwds_sample_o,
        .tx_clk_90_i     ( tx_clk_90    ),
        .hyper_cs_ni     ( &hyper_cs_no ),
        .hyper_rwds_i    ( hyper_rwds_i )
    );

    // Set and Reset RX clock enable
    always_ff @(posedge clk_i or negedge rst_ni) begin : proc_ff_rx_delay
        if (~rst_ni)                rx_rwds_clk_ena <= 1'b0;
        else if (rx_clk_set_i)      rx_rwds_clk_ena <= 1'b1;
        else if (rx_clk_reset_i)    rx_rwds_clk_ena <= 1'b0;
    end

    // Shift RWDS clock by 90 degrees
    // Gate delayed RWDS clock with RX clock enable
`ifdef SIM
    hyperbus_delay_behav i_delay_rx_rwds_90 (
        .in_i       ( hyper_rwds_i   ),
        .delay_i    ( rx_clk_delay_i ),
        .out_o      ( rx_rwds_90     )
    );

    tc_clk_gating i_rwds_in_clk_gate (
        .clk_i      ( rx_rwds_90        ),
        .en_i       ( rx_rwds_clk_ena   ),
        .test_en_i  ( test_mode_i       ),
        .clk_o      ( rx_rwds_clk       )
    );
`else
    hyperbus_delay i_delay_rx_rwds_90 (
        .in_i       ( hyper_rwds_i   ),
        .delay_i    ( rx_clk_delay_i ),
        .out_o      ( rx_rwds_90     )
    );

    CKLNQD20BWP7T30P140 i_rwds_in_clk_gate (
        .TE      ( test_mode_i       ),
        .E       ( rx_rwds_clk_ena   ),
        .CP      ( rx_rwds_90        ),
        .Q       ( rx_rwds_clk       )
    );
`endif

     // Reset RX state on async reset or on gated clock (whenever inactive)
     // TODO: is this safe? Replace with tech cells?
    assign rx_rwds_soft_rst = ~rst_ni | (~rx_rwds_clk_ena & ~test_mode_i);

    // RX data is valid one cycle after each RX soft reset
    always_ff @(posedge rx_rwds_clk or posedge rx_rwds_soft_rst) begin : proc_read_in_valid
        if (rx_rwds_soft_rst)   rx_rwds_fifo_valid <= 1'b0;
        else                    rx_rwds_fifo_valid <= 1'b1;
    end

    // Data input DDR conversion
    assign rx_rwds_fifo_in[7:0] = hyper_dq_i;
    always @(posedge rx_rwds_clk or posedge rx_rwds_soft_rst) begin : proc_ff_ddr_in
        if(rx_rwds_soft_rst)    rx_rwds_fifo_in[15:8] <= '0;
        else                    rx_rwds_fifo_in[15:8] <= hyper_dq_i;
    end

    tc_clk_inverter i_rwds_clk_inverter (
       .clk_i ( rx_rwds_clk   ),
       .clk_o ( rx_rwds_clk_n )
    );

    // Cross input data from RWDS domain into system domain
    cdc_fifo_gray  #(
        .T          ( logic [15:0]      ),
        .LOG_DEPTH  ( RxFifoLogDepth    ),
        .SYNC_STAGES( SyncStages        )
    ) i_rx_rwds_cdc_fifo (
        // RWDS domain
        .src_clk_i   ( rx_rwds_clk_n      ),
        .src_rst_ni  ( rst_ni             ),
        .src_data_i  ( rx_rwds_fifo_in    ),
        .src_valid_i ( rx_rwds_fifo_valid ),
        .src_ready_o ( rx_rwds_fifo_ready ),
        // System domain
        .dst_clk_i   ( clk_i        ),
        .dst_rst_ni  ( rst_ni       ),
        .dst_data_o  ( rx_data_o    ),
        .dst_valid_o ( rx_valid_o   ),
        .dst_ready_i ( rx_ready_i   )
    );

endmodule
