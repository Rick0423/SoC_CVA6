//////////////////////////////////////////////////////////////////////////////////
// Designer:        Mingxuan Li
// Acknowledgement: Cursor + Claude
// Date:            2025-03-28
// Design Name:     soc_pad_wrapper
// Project Name:    ISSCC26 ASR
// Description:     Connect SoC to external pads
//////////////////////////////////////////////////////////////////////////////////

module soc_pad_wrapper (
`ifdef SIM
    input   wire    sys_clk_i               ,
    input   wire    phy_clk_i               ,
    input   wire    rstn_i                  ,
`endif

    inout   wire    ext_clk_pad_i           ,
    inout   wire    dco_div_rstn_pad_i      ,

    inout   wire    rstn_pad_i              ,
    inout   wire    clk_led_pad_o           ,

    // JTAG
    inout   wire    jtag_tck_pad_i          ,
    inout   wire    jtag_tms_pad_i          ,
    inout   wire    jtag_tdi_pad_i          ,
    inout   wire    jtag_tdo_pad_o          ,

    // UART
    inout   wire    uart_rx_pad_i           ,
    inout   wire    uart_tx_pad_o           ,

    // Hyperbus
    inout   wire    hyper_rwds_pad_io       ,
    inout   wire    hyper_dq0_pad_io        ,
    inout   wire    hyper_dq1_pad_io        ,
    inout   wire    hyper_dq2_pad_io        ,
    inout   wire    hyper_dq3_pad_io        ,
    inout   wire    hyper_dq4_pad_io        ,
    inout   wire    hyper_dq5_pad_io        ,
    inout   wire    hyper_dq6_pad_io        ,
    inout   wire    hyper_dq7_pad_io        ,
    inout   wire    hyper_resetn_pad_o      ,
    inout   wire    hyper_csn_pad_o         ,
    inout   wire    hyper_ck_pad_o          ,
    inout   wire    hyper_ckn_pad_o         ,

    // System DCO Control
    inout   wire    sys_dco_en_pad_i        ,
    inout   wire    sys_clk_sel_pad_i       ,
    inout   wire    sys_dco_clk_div_pad_o   ,

    // Hyperbus PHY DCO Control
    inout   wire    phy_dco_en_pad_i        ,
    inout   wire    phy_clk_sel_pad_i       ,
    inout   wire    phy_dco_clk_div_pad_o   ,

    // PLL Control
    inout   wire    pll_dco_sel_pad_i       ,
    inout   wire    pll_clk_pad_o           ,
    inout   wire    pll_trigger_pad_o
);

    logic       dco_ext_clk_i       ;
    logic       dco_div_rstn_i      ;
    logic       rstn_i              ;
    logic       clk_led_o           ;
    logic       jtag_tck_i          ;
    logic       jtag_tms_i          ;
    logic       jtag_tdi_i          ;
    logic       jtag_tdo_o          ;
    logic       uart_rx_i           ;
    logic       uart_tx_o           ;
    logic       hyper_rwds_i        ;
    logic [7:0] hyper_dq_i          ;
    logic       hyper_resetn_o      ;
    logic       hyper_csn_o         ;
    logic       hyper_ck_o          ;
    logic       hyper_ckn_o         ;
    logic       hyper_rwds_oe_o     ;
    logic       hyper_dq_oe_o       ;
    logic       hyper_rwds_o        ;
    logic [7:0] hyper_dq_o          ;
    logic       sys_dco_en_i        ;
    logic       sys_clk_sel_i       ;
    logic       sys_dco_clk_div_o   ;
    logic       phy_dco_en_i        ;
    logic       phy_clk_sel_i       ;
    logic       phy_dco_clk_div_o   ;
    logic       pll_dco_sel_i       ;
    logic       pll_clk_o           ;
    logic       pll_trigger_o       ;

    soc soc_inst (
`ifdef SIM
        .sys_clk_i,
        .phy_clk_i,
`endif
        .dco_ext_clk_i,
        .dco_div_rstn_i,
        .rstn_i,
        .clk_led_o,
        .jtag_tck_i,
        .jtag_tms_i,
        .jtag_tdi_i,
        .jtag_tdo_o,
        .uart_rx_i,
        .uart_tx_o,
        .hyper_rwds_i,
        .hyper_dq_i,
        .hyper_resetn_o,
        .hyper_csn_o,
        .hyper_ck_o,
        .hyper_ckn_o,
        .hyper_rwds_oe_o,
        .hyper_dq_oe_o,
        .hyper_rwds_o,
        .hyper_dq_o,
        .sys_dco_en_i,
        .sys_clk_sel_i,
        .sys_dco_clk_div_o,
        .phy_dco_en_i,
        .phy_clk_sel_i,
        .phy_dco_clk_div_o,
        .pll_dco_sel_i,
        .pll_clk_o,
        .pll_trigger_o
    );

`ifdef SIM
    pad_functional_pd ext_clk_pad_inst (
        .PEN    (1'b0             ),
        .OEN    (1'b1             ),
        .I      (1'b0             ),
        .O      (dco_ext_clk_i    ),
        .PAD    (ext_clk_pad_i    )
    );

    pad_functional_pd dco_div_rstn_pad_inst (
        .PEN    (1'b0             ),
        .OEN    (1'b1             ),
        .I      (1'b0             ),
        .O      (dco_div_rstn_i   ),
        .PAD    (dco_div_rstn_pad_i)
    );

    pad_functional_pd clk_led_pad_inst (
        .PEN    (1'b0             ),
        .OEN    (1'b0             ),
        .I      (clk_led_o        ),
        .O      (/*unused*/       ),
        .PAD    (clk_led_pad_o    )
    );

    pad_functional_pd jtag_tck_pad_inst (
        .PEN    (1'b0             ),
        .OEN    (1'b1             ),
        .I      (1'b0             ),
        .O      (jtag_tck_i       ),
        .PAD    (jtag_tck_pad_i   )
    );

    pad_functional_pd jtag_tms_pad_inst (
        .PEN    (1'b0             ),
        .OEN    (1'b1             ),
        .I      (1'b0             ),
        .O      (jtag_tms_i       ),
        .PAD    (jtag_tms_pad_i   )
    );

    pad_functional_pd jtag_tdi_pad_inst (
        .PEN    (1'b0             ),
        .OEN    (1'b1             ),
        .I      (1'b0             ),
        .O      (jtag_tdi_i       ),
        .PAD    (jtag_tdi_pad_i   )
    );

    pad_functional_pd jtag_tdo_pad_inst (
        .PEN    (1'b0             ),
        .OEN    (1'b0             ),
        .I      (jtag_tdo_o       ),
        .O      (/*unused*/       ),
        .PAD    (jtag_tdo_pad_o   )
    );

    pad_functional_pd uart_rx_pad_inst (
        .PEN    (1'b0             ),
        .OEN    (1'b1             ),
        .I      (1'b0             ),
        .O      (uart_rx_i        ),
        .PAD    (uart_rx_pad_i    )
    );

    pad_functional_pd uart_tx_pad_inst (
        .PEN    (1'b0             ),
        .OEN    (1'b0             ),
        .I      (uart_tx_o        ),
        .O      (/*unused*/       ),
        .PAD    (uart_tx_pad_o    )
    );

    pad_functional_pd sys_dco_en_pad_inst (
        .PEN    (1'b0             ),
        .OEN    (1'b1             ),
        .I      (1'b0             ),
        .O      (sys_dco_en_i     ),
        .PAD    (sys_dco_en_pad_i )
    );

    pad_functional_pd sys_clk_sel_pad_inst (
        .PEN    (1'b0             ),
        .OEN    (1'b1             ),
        .I      (1'b0             ),
        .O      (sys_clk_sel_i    ),
        .PAD    (sys_clk_sel_pad_i)
    );

    pad_functional_pd phy_dco_en_pad_inst (
        .PEN    (1'b0             ),
        .OEN    (1'b1             ),
        .I      (1'b0             ),
        .O      (phy_dco_en_i     ),
        .PAD    (phy_dco_en_pad_i )
    );

    pad_functional_pd phy_clk_sel_pad_inst (
        .PEN    (1'b0             ),
        .OEN    (1'b1             ),
        .I      (1'b0             ),
        .O      (phy_clk_sel_i    ),
        .PAD    (phy_clk_sel_pad_i)
    );

    pad_functional_pd pll_dco_sel_pad_inst (
        .PEN    (1'b0             ),
        .OEN    (1'b1             ),
        .I      (1'b0             ),
        .O      (pll_dco_sel_i    ),
        .PAD    (pll_dco_sel_pad_i)
    );

    pad_functional_pd sys_dco_clk_div_pad_inst (
        .PEN    (1'b0             ),
        .OEN    (1'b0             ),
        .I      (sys_dco_clk_div_o),
        .O      (/*unused*/       ),
        .PAD    (sys_dco_clk_div_pad_o)
    );

    pad_functional_pd phy_dco_clk_div_pad_inst (
        .PEN    (1'b0             ),
        .OEN    (1'b0             ),
        .I      (phy_dco_clk_div_o),
        .O      (/*unused*/       ),
        .PAD    (phy_dco_clk_div_pad_o)
    );

    pad_functional_pd pll_clk_pad_inst (
        .PEN    (1'b0             ),
        .OEN    (1'b0             ),
        .I      (pll_clk_o        ),
        .O      (/*unused*/       ),
        .PAD    (pll_clk_pad_o    )
    );

    pad_functional_pd pll_trigger_pad_inst (
        .PEN    (1'b0             ),
        .OEN    (1'b0             ),
        .I      (pll_trigger_o    ),
        .O      (/*unused*/       ),
        .PAD    (pll_trigger_pad_o)
    );

    pad_functional_pd hyper_dq0_pad_inst (
        .PEN    (1'b0             ),
        .OEN    (~hyper_dq_oe_o   ),
        .I      (hyper_dq_o[0]    ),
        .O      (hyper_dq_i[0]    ),
        .PAD    (hyper_dq0_pad_io )
    );

    pad_functional_pd hyper_dq1_pad_inst (
        .PEN    (1'b0             ),
        .OEN    (~hyper_dq_oe_o   ),
        .I      (hyper_dq_o[1]    ),
        .O      (hyper_dq_i[1]    ),
        .PAD    (hyper_dq1_pad_io )
    );

    pad_functional_pd hyper_dq2_pad_inst (
        .PEN    (1'b0             ),
        .OEN    (~hyper_dq_oe_o   ),
        .I      (hyper_dq_o[2]    ),
        .O      (hyper_dq_i[2]    ),
        .PAD    (hyper_dq2_pad_io )
    );

    pad_functional_pd hyper_dq3_pad_inst (
        .PEN    (1'b0             ),
        .OEN    (~hyper_dq_oe_o   ),
        .I      (hyper_dq_o[3]    ),
        .O      (hyper_dq_i[3]    ),
        .PAD    (hyper_dq3_pad_io )
    );

    pad_functional_pd hyper_dq4_pad_inst (
        .PEN    (1'b0             ),
        .OEN    (~hyper_dq_oe_o   ),
        .I      (hyper_dq_o[4]    ),
        .O      (hyper_dq_i[4]    ),
        .PAD    (hyper_dq4_pad_io )
    );

    pad_functional_pd hyper_dq5_pad_inst (
        .PEN    (1'b0             ),
        .OEN    (~hyper_dq_oe_o   ),
        .I      (hyper_dq_o[5]    ),
        .O      (hyper_dq_i[5]    ),
        .PAD    (hyper_dq5_pad_io )
    );

    pad_functional_pd hyper_dq6_pad_inst (
        .PEN    (1'b0             ),
        .OEN    (~hyper_dq_oe_o   ),
        .I      (hyper_dq_o[6]    ),
        .O      (hyper_dq_i[6]    ),
        .PAD    (hyper_dq6_pad_io )
    );

    pad_functional_pd hyper_dq7_pad_inst (
        .PEN    (1'b0             ),
        .OEN    (~hyper_dq_oe_o   ),
        .I      (hyper_dq_o[7]    ),
        .O      (hyper_dq_i[7]    ),
        .PAD    (hyper_dq7_pad_io )
    );

    pad_functional_pd hyper_rwds_pad_inst (
        .PEN    (1'b0             ),
        .OEN    (~hyper_rwds_oe_o),
        .I      (hyper_rwds_o     ),
        .O      (hyper_rwds_i     ),
        .PAD    (hyper_rwds_pad_io)
    );

    pad_functional_pd hyper_resetn_pad_inst (
        .PEN    (1'b0             ),
        .OEN    (1'b0             ),
        .I      (hyper_resetn_o   ),
        .O      (/*unused*/       ),
        .PAD    (hyper_resetn_pad_o)
    );

    pad_functional_pd hyper_csn_pad_inst (
        .PEN    (1'b0             ),
        .OEN    (1'b0             ),
        .I      (hyper_csn_o      ),
        .O      (/*unused*/       ),
        .PAD    (hyper_csn_pad_o  )
    );

    pad_functional_pd hyper_ck_pad_inst (
        .PEN    (1'b0             ),
        .OEN    (1'b0             ),
        .I      (hyper_ck_o       ),
        .O      (/*unused*/       ),
        .PAD    (hyper_ck_pad_o   )
    );

    pad_functional_pd hyper_ckn_pad_inst (
        .PEN    (1'b0             ),
        .OEN    (1'b0             ),
        .I      (hyper_ckn_o      ),
        .O      (/*unused*/       ),
        .PAD    (hyper_ckn_pad_o  )
    );


`else
    PDDWUW0408SDGH_V ext_clk_pad_inst (
        .PU     (1'b0             ),
        .PD     (1'b0             ),
        .DS     (1'b0             ),
        .IE     (1'b1             ),
        .OEN    (1'b1             ),
        .I      (1'b0             ),
        .C      (dco_ext_clk_i    ),
        .PAD    (ext_clk_pad_i    )
    );

    PDDWUW0408SDGH_V dco_div_rstn_pad_inst (
        .PU     (1'b0              ),
        .PD     (1'b0              ),
        .DS     (1'b0              ),
        .IE     (1'b1              ),
        .OEN    (1'b1              ),
        .I      (1'b0              ),
        .C      (dco_div_rstn_i    ),
        .PAD    (dco_div_rstn_pad_i)
    );

    PDDWUW0408SDGH_V rstn_pad_inst (
        .PU     (1'b0             ),
        .PD     (1'b0             ),
        .DS     (1'b0             ),
        .IE     (1'b1             ),
        .OEN    (1'b1             ),
        .I      (1'b0             ),
        .C      (rstn_i           ),
        .PAD    (rstn_pad_i       )
    );

    PDDWUW0408SDGH_V jtag_tck_pad_inst (
        .PU     (1'b0             ),
        .PD     (1'b0             ),
        .DS     (1'b0             ),
        .IE     (1'b1             ),
        .OEN    (1'b1             ),
        .I      (1'b0             ),
        .C      (jtag_tck_i       ),
        .PAD    (jtag_tck_pad_i   )
    );

    PDDWUW0408SDGH_V jtag_tms_pad_inst (
        .PU     (1'b0             ),
        .PD     (1'b0             ),
        .DS     (1'b0             ),
        .IE     (1'b1             ),
        .OEN    (1'b1             ),
        .I      (1'b0             ),
        .C      (jtag_tms_i       ),
        .PAD    (jtag_tms_pad_i   )
    );

    PDDWUW0408SDGH_V jtag_tdi_pad_inst (
        .PU     (1'b0             ),
        .PD     (1'b0             ),
        .DS     (1'b0             ),
        .IE     (1'b1             ),
        .OEN    (1'b1             ),
        .I      (1'b0             ),
        .C      (jtag_tdi_i       ),
        .PAD    (jtag_tdi_pad_i   )
    );

    PDDWUW0408SDGH_V uart_rx_pad_inst (
        .PU     (1'b0             ),
        .PD     (1'b0             ),
        .DS     (1'b0             ),
        .IE     (1'b1             ),
        .OEN    (1'b1             ),
        .I      (1'b0             ),
        .C      (uart_rx_i        ),
        .PAD    (uart_rx_pad_i    )
    );

    PDDWUW0408SDGH_V sys_dco_en_pad_inst (
        .PU     (1'b0             ),
        .PD     (1'b0             ),
        .DS     (1'b0             ),
        .IE     (1'b1             ),
        .OEN    (1'b1             ),
        .I      (1'b0             ),
        .C      (sys_dco_en_i     ),
        .PAD    (sys_dco_en_pad_i )
    );

    PDDWUW0408SDGH_V sys_clk_sel_pad_inst (
        .PU     (1'b0             ),
        .PD     (1'b0             ),
        .DS     (1'b0             ),
        .IE     (1'b1             ),
        .OEN    (1'b1             ),
        .I      (1'b0             ),
        .C      (sys_clk_sel_i    ),
        .PAD    (sys_clk_sel_pad_i)
    );

    PDDWUW0408SDGH_V phy_dco_en_pad_inst (
        .PU     (1'b0             ),
        .PD     (1'b0             ),
        .DS     (1'b0             ),
        .IE     (1'b1             ),
        .OEN    (1'b1             ),
        .I      (1'b0             ),
        .C      (phy_dco_en_i     ),
        .PAD    (phy_dco_en_pad_i )
    );

    PDDWUW0408SDGH_V phy_clk_sel_pad_inst (
        .PU     (1'b0             ),
        .PD     (1'b0             ),
        .DS     (1'b0             ),
        .IE     (1'b1             ),
        .OEN    (1'b1             ),
        .I      (1'b0             ),
        .C      (phy_clk_sel_i    ),
        .PAD    (phy_clk_sel_pad_i)
    );

    PDDWUW0408SDGH_V clk_led_pad_inst (
        .PU     (1'b0             ),
        .PD     (1'b0             ),
        .DS     (1'b1             ),
        .IE     (1'b0             ),
        .OEN    (1'b0             ),
        .I      (clk_led_o        ),
        .C      (/*unused*/       ),
        .PAD    (clk_led_pad_o    )
    );

    PDDWUW0408SDGH_V jtag_tdo_pad_inst (
        .PU     (1'b0             ),
        .PD     (1'b0             ),
        .DS     (1'b1             ),
        .IE     (1'b0             ),
        .OEN    (1'b0             ),
        .I      (jtag_tdo_o       ),
        .C      (/*unused*/       ),
        .PAD    (jtag_tdo_pad_o   )
    );

    PDDWUW0408SDGH_V uart_tx_pad_inst (
        .PU     (1'b0             ),
        .PD     (1'b0             ),
        .DS     (1'b1             ),
        .IE     (1'b0             ),
        .OEN    (1'b0             ),
        .I      (uart_tx_o        ),
        .C      (/*unused*/       ),
        .PAD    (uart_tx_pad_o    )
    );

    PDDWUW0408SDGH_V sys_dco_clk_div_pad_inst (
        .PU     (1'b0             ),
        .PD     (1'b0             ),
        .DS     (1'b1             ),
        .IE     (1'b0             ),
        .OEN    (1'b0             ),
        .I      (sys_dco_clk_div_o),
        .C      (/*unused*/       ),
        .PAD    (sys_dco_clk_div_pad_o)
    );

    PDDWUW0408SDGH_V phy_dco_clk_div_pad_inst (
        .PU     (1'b0             ),
        .PD     (1'b0             ),
        .DS     (1'b1             ),
        .IE     (1'b0             ),
        .OEN    (1'b0             ),
        .I      (phy_dco_clk_div_o),
        .C      (/*unused*/       ),
        .PAD    (phy_dco_clk_div_pad_o)
    );

    PDDWUW0408SDGH_H pll_dco_sel_pad_inst (
        .PU     (1'b0             ),
        .PD     (1'b0             ),
        .DS     (1'b0             ),
        .IE     (1'b1             ),
        .OEN    (1'b1             ),
        .I      (1'b0             ),
        .C      (pll_dco_sel_i    ),
        .PAD    (pll_dco_sel_pad_i)
    );

    PDDWUW0408SDGH_H pll_clk_pad_inst (
        .PU     (1'b0             ),
        .PD     (1'b0             ),
        .DS     (1'b1             ),
        .IE     (1'b0             ),
        .OEN    (1'b0             ),
        .I      (pll_clk_o        ),
        .C      (/*unused*/       ),
        .PAD    (pll_clk_pad_o    )
    );

    PDDWUW0408SDGH_H pll_trigger_pad_inst (
        .PU     (1'b0             ),
        .PD     (1'b0             ),
        .DS     (1'b1             ),
        .IE     (1'b0             ),
        .OEN    (1'b0             ),
        .I      (pll_trigger_o    ),
        .C      (/*unused*/       ),
        .PAD    (pll_trigger_pad_o)
    );

    PDDWUW0408SDGH_H hyper_resetn_pad_inst (
        .PU     (1'b0             ),
        .PD     (1'b0             ),
        .DS     (1'b1             ),
        .IE     (1'b0             ),
        .OEN    (1'b0             ),
        .I      (hyper_resetn_o   ),
        .C      (/*unused*/       ),
        .PAD    (hyper_resetn_pad_o)
    );

    PDDWUW0408SDGH_H hyper_csn_pad_inst (
        .PU     (1'b0             ),
        .PD     (1'b0             ),
        .DS     (1'b1             ),
        .IE     (1'b0             ),
        .OEN    (1'b0             ),
        .I      (hyper_csn_o      ),
        .C      (/*unused*/       ),
        .PAD    (hyper_csn_pad_o  )
    );

    PDDWUW0408SDGH_H hyper_ck_pad_inst (
        .PU     (1'b0             ),
        .PD     (1'b0             ),
        .DS     (1'b1             ),
        .IE     (1'b0             ),
        .OEN    (1'b0             ),
        .I      (hyper_ck_o       ),
        .C      (/*unused*/       ),
        .PAD    (hyper_ck_pad_o   )
    );

    PDDWUW0408SDGH_H hyper_ckn_pad_inst (
        .PU     (1'b0             ),
        .PD     (1'b0             ),
        .DS     (1'b1             ),
        .IE     (1'b0             ),
        .OEN    (1'b0             ),
        .I      (hyper_ckn_o      ),
        .C      (/*unused*/       ),
        .PAD    (hyper_ckn_pad_o  )
    );

    PDDWUW0408SDGH_H hyper_rwds_pad_inst (
        .PU     (1'b0             ),
        .PD     (1'b0             ),
        .DS     (hyper_rwds_oe_o  ),
        .IE     (1'b1             ),
        .OEN    (~hyper_rwds_oe_o ),
        .I      (hyper_rwds_o     ),
        .C      (hyper_rwds_i     ),
        .PAD    (hyper_rwds_pad_io)
    );

    PDDWUW0408SDGH_H hyper_dq0_pad_inst (
        .PU     (1'b0             ),
        .PD     (1'b0             ),
        .DS     (hyper_dq_oe_o    ),
        .IE     (1'b1             ),
        .OEN    (~hyper_dq_oe_o   ),
        .I      (hyper_dq_o[0]    ),
        .C      (hyper_dq_i[0]    ),
        .PAD    (hyper_dq0_pad_io )
    );

    PDDWUW0408SDGH_H hyper_dq1_pad_inst (
        .PU     (1'b0             ),
        .PD     (1'b0             ),
        .DS     (hyper_dq_oe_o    ),
        .IE     (1'b1             ),
        .OEN    (~hyper_dq_oe_o   ),
        .I      (hyper_dq_o[1]    ),
        .C      (hyper_dq_i[1]    ),
        .PAD    (hyper_dq1_pad_io )
    );

    PDDWUW0408SDGH_H hyper_dq2_pad_inst (
        .PU     (1'b0             ),
        .PD     (1'b0             ),
        .DS     (hyper_dq_oe_o    ),
        .IE     (1'b1             ),
        .OEN    (~hyper_dq_oe_o   ),
        .I      (hyper_dq_o[2]    ),
        .C      (hyper_dq_i[2]    ),
        .PAD    (hyper_dq2_pad_io )
    );

    PDDWUW0408SDGH_H hyper_dq3_pad_inst (
        .PU     (1'b0             ),
        .PD     (1'b0             ),
        .DS     (hyper_dq_oe_o    ),
        .IE     (1'b1             ),
        .OEN    (~hyper_dq_oe_o   ),
        .I      (hyper_dq_o[3]    ),
        .C      (hyper_dq_i[3]    ),
        .PAD    (hyper_dq3_pad_io )
    );

    PDDWUW0408SDGH_H hyper_dq4_pad_inst (
        .PU     (1'b0             ),
        .PD     (1'b0             ),
        .DS     (hyper_dq_oe_o    ),
        .IE     (1'b1             ),
        .OEN    (~hyper_dq_oe_o   ),
        .I      (hyper_dq_o[4]    ),
        .C      (hyper_dq_i[4]    ),
        .PAD    (hyper_dq4_pad_io )
    );

    PDDWUW0408SDGH_H hyper_dq5_pad_inst (
        .PU     (1'b0             ),
        .PD     (1'b0             ),
        .DS     (hyper_dq_oe_o    ),
        .IE     (1'b1             ),
        .OEN    (~hyper_dq_oe_o   ),
        .I      (hyper_dq_o[5]    ),
        .C      (hyper_dq_i[5]    ),
        .PAD    (hyper_dq5_pad_io )
    );

    PDDWUW0408SDGH_H hyper_dq6_pad_inst (
        .PU     (1'b0             ),
        .PD     (1'b0             ),
        .DS     (hyper_dq_oe_o    ),
        .IE     (1'b1             ),
        .OEN    (~hyper_dq_oe_o   ),
        .I      (hyper_dq_o[6]    ),
        .C      (hyper_dq_i[6]    ),
        .PAD    (hyper_dq6_pad_io )
    );

    PDDWUW0408SDGH_H hyper_dq7_pad_inst (
        .PU     (1'b0             ),
        .PD     (1'b0             ),
        .DS     (hyper_dq_oe_o    ),
        .IE     (1'b1             ),
        .OEN    (~hyper_dq_oe_o   ),
        .I      (hyper_dq_o[7]    ),
        .C      (hyper_dq_i[7]    ),
        .PAD    (hyper_dq7_pad_io )
    );
`endif

endmodule
