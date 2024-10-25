module testbench;

    // Testbench parameters
    parameter int NUM_AHB = 2;       // Number of AHB interfaces
    parameter int NUM_APB = 4;       // Number of APB peripherals
    parameter int ADDR_WIDTH = 32;
    parameter int DATA_WIDTH = 32;
    parameter int APB_BASE_ADDR = 32'h80000000;
    parameter int APB_ADDR_RANGE = 32'h00001000;
    parameter int clk_div = 1;       // Clock division factor for PCLK relative to HCLK

    // Clock and reset signals
    logic HCLK;
    logic PCLK;
    logic HRESETn;

    // AHB signals
    logic [ADDR_WIDTH-1:0] HADDR     [NUM_AHB-1:0];
    logic [DATA_WIDTH-1:0] HWDATA    [NUM_AHB-1:0];
    logic [1:0]            HTRANS    [NUM_AHB-1:0];
    logic                  HWRITE    [NUM_AHB-1:0];
    logic                  HREADY    [NUM_AHB-1:0];
    logic [3:0]            HPROT     [NUM_AHB-1:0];
    logic                  HSEL      [NUM_AHB-1:0];
    logic [DATA_WIDTH-1:0] HRDATA    [NUM_AHB-1:0];
    logic                  HRESP     [NUM_AHB-1:0];
    logic                  HMASTLOCK [NUM_AHB-1:0];
    logic                  HNONSEC   [NUM_AHB-1:0];
    logic [3:0]            HCID      [NUM_AHB-1:0];

    // Shared APB bus signals
    logic [ADDR_WIDTH-1:0] PADDR;
    logic [DATA_WIDTH-1:0] PWDATA;
    logic                  PWRITE;
    logic [NUM_APB-1:0]    PSEL;
    logic                  PENABLE;
    logic [DATA_WIDTH-1:0] PRDATA;
    logic                  PSLVERROR;
    logic                  PREADY;

    // Illegal access detection signals
    logic sec_ilac [NUM_APB-1:0];
    logic cid_ilac [NUM_APB-1:0];
    logic priv_ilac [NUM_APB-1:0];

    // Instantiate the xAHB2APB bridge with arbitration and PCLK synchronization
    xAHB2APB #(
        .NUM_AHB(NUM_AHB),
        .NUM_APB(NUM_APB),
        .ARB_TYPE(0), // Round-robin arbitration
        .WEIGHT_0(1), // Not used for round-robin, but set for weighted round-robin
        .WEIGHT_1(1),
        .APB_BASE_ADDR(APB_BASE_ADDR),
        .APB_ADDR_RANGE(APB_ADDR_RANGE),
        .clk_div(clk_div)
    ) dut (
        .HCLK(HCLK),
        .PCLK(PCLK),
        .HRESETn(HRESETn),
        .HADDR(HADDR),
        .HWDATA(HWDATA),
        .HWRITE(HWRITE),
        .HTRANS(HTRANS),
        .HPROT(HPROT),
        .HSEL(HSEL),
        .HREADY(HREADY),
        .HRDATA(HRDATA),
        .HRESP(HRESP),
        .HMASTLOCK(HMASTLOCK),
        .HNONSEC(HNONSEC),
        .HCID(HCID),
        .PADDR(PADDR),
        .PWDATA(PWDATA),
        .PWRITE(PWRITE),
        .PSEL(PSEL),
        .PENABLE(PENABLE),
        .PRDATA(PRDATA),
        .PSLVERROR(PSLVERROR),
        .PREADY(PREADY),
        .sec_ilac(sec_ilac),
        .cid_ilac(cid_ilac),
        .priv_ilac(priv_ilac)
    );

    // Instantiate multiple APB peripherals
    genvar i;
    generate
        for (i = 0; i < NUM_APB; i++) begin : apb_peripherals
            apb_per #(
                .ADDR_WIDTH(ADDR_WIDTH),
                .DATA_WIDTH(DATA_WIDTH)
            ) apb_slave (
                .PCLK(PCLK),
                .PRESETn(HRESETn),
                .PADDR(PADDR),          // Shared APB address bus
                .PWDATA(PWDATA),        // Shared APB write data bus
                .PWRITE(PWRITE),        // Shared APB write enable
                .PSEL(PSEL[i]),         // Peripheral select
                .PENABLE(PENABLE),      // Shared APB enable signal
                .PRDATA(PRDATA),        // Shared APB read data bus
                .PSLVERROR(PSLVERROR),  // Shared APB slave error
                .PREADY(PREADY)         // Shared APB ready signal
            );
        end
    endgenerate

    // Clock generation
    initial begin
        HCLK = 0;
        forever #5 HCLK = ~HCLK;  // 100 MHz HCLK
    end

    // PCLK generation based on clk_div parameter
    initial begin
        PCLK = 0;
        forever begin
            repeat(clk_div) @(posedge HCLK); // Wait for clk_div HCLK cycles
            PCLK = ~PCLK;
        end
    end

    // Reset generation
    initial begin
        HRESETn = 0;
        #20 HRESETn = 1;
    end

    // AHB random transaction generator
    AHB5_Random_Transaction_Generator #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) ahb_gen_0 (
        .HCLK(HCLK),
        .HRESETn(HRESETn),
        .HADDR(HADDR[0]),
        .HWDATA(HWDATA[0]),
        .HWRITE(HWRITE[0]),
        .HTRANS(HTRANS[0]),
        .HPROT(HPROT[0]),
        .HSEL(HSEL[0]),
        .HREADY(HREADY[0])
    );

    AHB5_Random_Transaction_Generator #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) ahb_gen_1 (
        .HCLK(HCLK),
        .HRESETn(HRESETn),
        .HADDR(HADDR[1]),
        .HWDATA(HWDATA[1]),
        .HWRITE(HWRITE[1]),
        .HTRANS(HTRANS[1]),
        .HPROT(HPROT[1]),
        .HSEL(HSEL[1]),
        .HREADY(HREADY[1])
    );

    // Simulation control
    initial begin
        // Start the random transaction generators
        ahb_gen_0.start_random_transactions();
        ahb_gen_1.start_random_transactions();

        // Monitor the APB signals
        $monitor("Time: %t | APB PADDR: %h PWDATA: %h PWRITE: %b PSEL: %b PENABLE: %b PRDATA: %h PSLVERROR: %b PREADY: %b",
                 $time, PADDR, PWDATA, PWRITE, PSEL, PENABLE, PRDATA, PSLVERROR, PREADY);

        // Run the simulation for a fixed amount of time
        #1000 $stop;
    end

endmodule
