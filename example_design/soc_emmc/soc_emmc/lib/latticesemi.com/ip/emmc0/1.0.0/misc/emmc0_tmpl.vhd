component emmc0 is
    port(
        rst_n_i: in std_logic;
        clk_i: in std_logic;
        emmc_clk_o: out std_logic;
        emmc_cmd_io: inout std_logic;
        emmc_dat_io: inout std_logic_vector(7 downto 0);
        emmc_rst_n_o: out std_logic;
        int_o: out std_logic;
        m_axi4_awready_i: in std_logic;
        m_axi4_awvalid_o: out std_logic;
        m_axi4_awid_o: out std_logic_vector(2 downto 0);
        m_axi4_awaddr_o: out std_logic_vector(31 downto 0);
        m_axi4_awlen_o: out std_logic_vector(7 downto 0);
        m_axi4_awsize_o: out std_logic_vector(2 downto 0);
        m_axi4_awburst_o: out std_logic_vector(1 downto 0);
        m_axi4_awprot_o: out std_logic_vector(2 downto 0);
        m_axi4_wready_i: in std_logic;
        m_axi4_wvalid_o: out std_logic;
        m_axi4_wdata_o: out std_logic_vector(31 downto 0);
        m_axi4_wstrb_o: out std_logic_vector(3 downto 0);
        m_axi4_wlast_o: out std_logic;
        m_axi4_bready_o: out std_logic;
        m_axi4_bvalid_i: in std_logic;
        m_axi4_bid_i: in std_logic_vector(2 downto 0);
        m_axi4_bresp_i: in std_logic_vector(1 downto 0);
        m_axi4_arready_i: in std_logic;
        m_axi4_arvalid_o: out std_logic;
        m_axi4_arid_o: out std_logic_vector(2 downto 0);
        m_axi4_araddr_o: out std_logic_vector(31 downto 0);
        m_axi4_arlen_o: out std_logic_vector(7 downto 0);
        m_axi4_arsize_o: out std_logic_vector(2 downto 0);
        m_axi4_arburst_o: out std_logic_vector(1 downto 0);
        m_axi4_arprot_o: out std_logic_vector(2 downto 0);
        m_axi4_rvalid_i: in std_logic;
        m_axi4_rready_o: out std_logic;
        m_axi4_rid_i: in std_logic_vector(2 downto 0);
        m_axi4_rdata_i: in std_logic_vector(31 downto 0);
        m_axi4_rresp_i: in std_logic_vector(1 downto 0);
        m_axi4_rlast_i: in std_logic;
        s_apb_penable_i: in std_logic;
        s_apb_psel_i: in std_logic;
        s_apb_pwrite_i: in std_logic;
        s_apb_paddr_i: in std_logic_vector(31 downto 0);
        s_apb_pwdata_i: in std_logic_vector(31 downto 0);
        s_apb_pready_o: out std_logic;
        s_apb_pslverr_o: out std_logic;
        s_apb_prdata_o: out std_logic_vector(31 downto 0)
    );
end component;

__: emmc0 port map(
    rst_n_i=>,
    clk_i=>,
    emmc_clk_o=>,
    emmc_cmd_io=>,
    emmc_dat_io=>,
    emmc_rst_n_o=>,
    int_o=>,
    m_axi4_awready_i=>,
    m_axi4_awvalid_o=>,
    m_axi4_awid_o=>,
    m_axi4_awaddr_o=>,
    m_axi4_awlen_o=>,
    m_axi4_awsize_o=>,
    m_axi4_awburst_o=>,
    m_axi4_awprot_o=>,
    m_axi4_wready_i=>,
    m_axi4_wvalid_o=>,
    m_axi4_wdata_o=>,
    m_axi4_wstrb_o=>,
    m_axi4_wlast_o=>,
    m_axi4_bready_o=>,
    m_axi4_bvalid_i=>,
    m_axi4_bid_i=>,
    m_axi4_bresp_i=>,
    m_axi4_arready_i=>,
    m_axi4_arvalid_o=>,
    m_axi4_arid_o=>,
    m_axi4_araddr_o=>,
    m_axi4_arlen_o=>,
    m_axi4_arsize_o=>,
    m_axi4_arburst_o=>,
    m_axi4_arprot_o=>,
    m_axi4_rvalid_i=>,
    m_axi4_rready_o=>,
    m_axi4_rid_i=>,
    m_axi4_rdata_i=>,
    m_axi4_rresp_i=>,
    m_axi4_rlast_i=>,
    s_apb_penable_i=>,
    s_apb_psel_i=>,
    s_apb_pwrite_i=>,
    s_apb_paddr_i=>,
    s_apb_pwdata_i=>,
    s_apb_pready_o=>,
    s_apb_pslverr_o=>,
    s_apb_prdata_o=>
);
