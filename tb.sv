module tb_xAHB2APB;

    // Testbench parameters
    parameter int NUM_AHB = 2;
    parameter int NUM_APB = 1;
    parameter int ADDR_WIDTH = 32;
    parameter int DATA_WIDTH = 32;

    // Clock and reset signals
    logic HCLK;
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

    // APB signals
    logic [ADDR_WIDTH-1:0] PADDR;
    logic [DATA_WIDTH-1:0] PWDATA;
    logic                  PWRITE;
    logic                  PSEL;
    logic                  PENABLE;
    logic [DATA_WIDTH-1:0] PRDATA;
    logic                  PSLVERROR;
    logic                  PREADY;

    // Illegal access detection signals
    logic sec_ilac [NUM_APB-1:0];
    logic cid_ilac [NUM_APB-1:0];
    logic priv_ilac [NUM_APB-1:0];

    // Instantiate the xAHB2APB bridge
    xAHB2APB #(
        .NUM_AHB(NUM_AHB),
        .NUM_APB(NUM_APB),
        .APB_SECURE(1'b1),            // Secure attribute for the APB peripheral
        .APB_CID('{4'b0000}),          // Compartment ID for the APB peripheral
        .APB_PRIV('{4'b0000})          // Privilege level for the APB peripheral
    ) dut (
        .HCLK(HCLK),
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

    // Instantiate a simple APB peripheral
    simple_apb_peripheral #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) apb_slave (
        .PCLK(HCLK),
        .PRESETn(HRESETn),
        .PADDR(PADDR),
        .PWDATA(PWDATA),
        .PWRITE(PWRITE),
        .PSEL(PSEL),
        .PENABLE(PENABLE),
        .PRDATA(PRDATA),
        .PSLVERROR(PSLVERROR),
        .PREADY(PREADY)
    );

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

    // Clock generation
    initial begin
        HCLK = 0;
        forever #5 HCLK = ~HCLK;  // 100 MHz clock
    end

    // Reset generation
    initial begin
        HRESETn = 0;
        #20 HRESETn = 1;
    end

    // Simulation control
    initial begin
        // Start the random transaction generator
        ahb_gen_0.start_random_transactions();
        
        // Monitor the APB signals
        $monitor("Time: %t | APB PADDR: %h PWDATA: %h PWRITE: %b PSEL: %b PENABLE: %b PRDATA: %h PSLVERROR: %b PREADY: %b",
                 $time, PADDR, PWDATA, PWRITE, PSEL, PENABLE, PRDATA, PSLVERROR, PREADY);

        // Run the simulation for a fixed amount of time
        #1000 $stop;
    end

endmodule

// Simple APB peripheral module
module simple_apb_peripheral #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32
)(
    input  logic              PCLK,
    input  logic              PRESETn,
    input  logic [ADDR_WIDTH-1:0] PADDR,
    input  logic [DATA_WIDTH-1:0] PWDATA,
    input  logic              PWRITE,
    input  logic              PSEL,
    input  logic              PENABLE,
    output logic [DATA_WIDTH-1:0] PRDATA,
    output logic              PSLVERROR,
    output logic              PREADY
);

    // Internal memory to store data
    logic [DATA_WIDTH-1:0] memory [0:255];

    // APB response logic
    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            PRDATA     <= 32'h0;
            PSLVERROR  <= 1'b0;
            PREADY     <= 1'b1;
        end else if (PSEL && PENABLE) begin
            PREADY <= 1'b1;
            if (PWRITE) begin
                memory[PADDR] <= PWDATA;  // Write operation
            end else begin
                PRDATA <= memory[PADDR];  // Read operation
            end
        end else begin
            PREADY <= 1'b1;
        end
    end
endmodule
