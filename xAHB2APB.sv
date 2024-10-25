module xAHB2APB #(
    parameter int NUM_AHB = 2,             // Number of AHB interfaces
    parameter int NUM_APB = 4,             // Number of APB peripherals
    parameter int ARB_TYPE = 0,            // Arbitration type: 0 = round-robin, 1 = fixed-priority, 2 = weighted round-robin
    parameter int WEIGHT_0 = 1,            // Weight for AHB interface 0 (for weighted round-robin)
    parameter int WEIGHT_1 = 1,            // Weight for AHB interface 1 (for weighted round-robin)
    parameter int APB_BASE_ADDR = 32'h80000000,  // Base address for APB peripherals
    parameter int APB_ADDR_RANGE = 32'h00001000, // Address range for each APB peripheral
    parameter int clk_div = 1              // Division factor for PCLK relative to HCLK
)(
    input  logic        HCLK,              // AHB clock signal
    input  logic        PCLK,              // APB clock signal (synchronous to HCLK but slower)
    input  logic        HRESETn,           // Active-low reset signal for AHB

    // AHB interface signals
    input  logic [31:0] HADDR     [NUM_AHB-1:0],   // AHB address signals
    input  logic [31:0] HWDATA    [NUM_AHB-1:0],   // AHB write data signals
    input  logic        HWRITE    [NUM_AHB-1:0],   // AHB write enable signals
    input  logic [2:0]  HSIZE     [NUM_AHB-1:0],   // AHB transfer size signals
    input  logic [3:0]  HPROT     [NUM_AHB-1:0],   // AHB protection control signals
    input  logic        HSEL      [NUM_AHB-1:0],   // AHB select signals
    input  logic        HREADY    [NUM_AHB-1:0],   // AHB ready signals
    output logic [31:0] HRDATA    [NUM_AHB-1:0],   // AHB read data signals
    output logic        HRESP     [NUM_AHB-1:0],   // AHB response signals

    // Shared APB bus signals
    output logic [31:0] PADDR,     // APB address
    output logic [31:0] PWDATA,    // APB write data
    output logic        PWRITE,    // APB write enable
    output logic        PENABLE,   // APB enable
    output logic [3:0]  PSTRB,     // APB write strobe
    input  logic [31:0] PRDATA,    // APB read data
    input  logic        PSLVERROR, // APB slave error
    input  logic        PREADY,    // APB ready signal

    // APB peripheral select signals
    output logic [NUM_APB-1:0] PSEL, // Peripheral select signals

    // Illegal access detection outputs for each APB peripheral
    output logic [NUM_APB-1:0] sec_ilac,   // Illegal secure access signal for each APB peripheral
    output logic [NUM_APB-1:0] cid_ilac,   // Illegal compartment ID access signal for each APB peripheral
    output logic [NUM_APB-1:0] priv_ilac   // Illegal privilege access signal for each APB peripheral
);

    // State machine states
    typedef enum logic [2:0] {
        IDLE,       // Waiting for AHB transaction
        SELECT,     // Select APB peripheral based on address
        SETUP,      // Setup phase of APB transaction
        ENABLE,     // Enable phase of APB transaction
        RESPONSE    // Capture APB response and complete transaction
    } state_t;

    state_t state, next_state;             // Current and next states
    logic [$clog2(NUM_AHB)-1:0] selected_ahb; // Selected AHB interface
    int weight_counter = 0;                // Counter for weighted round-robin arbitration

    // Synchronization to PCLK
    logic [31:0] clk_div_counter;          // Counter to track PCLK cycles in relation to HCLK
    logic enable_pclk_state;               // Indicates when PCLK is active for the APB state machine

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            clk_div_counter <= 0;
            enable_pclk_state <= 1'b0;
        end else begin
            // Increment the counter and toggle enable_pclk_state at each clk_div interval
            if (clk_div_counter == (clk_div - 1)) begin
                clk_div_counter <= 0;
                enable_pclk_state <= 1'b1;
            end else begin
                clk_div_counter <= clk_div_counter + 1;
                enable_pclk_state <= 1'b0;
            end
        end
    end

    // Clock synchronization
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            state <= IDLE;
        end else if (enable_pclk_state) begin
            state <= next_state;
        end
    end

    // State machine and next state logic
    always_comb begin
        next_state = state; // Default to stay in current state
        PSEL = '0;          // Default: No APB peripheral selected
        PENABLE = 0;        // Default: Disable APB transaction

        case (state)
            IDLE: begin
                if (HSEL[selected_ahb] && HREADY[selected_ahb]) begin
                    next_state = SELECT;
                end
            end

            SELECT: begin
                // Determine which APB peripheral to select based on address range
                for (int i = 0; i < NUM_APB; i++) begin
                    if ((HADDR[selected_ahb] >= APB_BASE_ADDR + i * APB_ADDR_RANGE) &&
                        (HADDR[selected_ahb] < APB_BASE_ADDR + (i + 1) * APB_ADDR_RANGE)) begin
                        PSEL[i] = 1'b1;
                    end
                end
                next_state = SETUP;
            end

            SETUP: begin
                PADDR   = HADDR[selected_ahb];
                PWDATA  = HWDATA[selected_ahb];
                PWRITE  = HWRITE[selected_ahb];
                // Set PSTRB based on HSIZE for APB4 write strobes
                case (HSIZE[selected_ahb])
                    3'b000: PSTRB = 4'b0001;
                    3'b001: PSTRB = 4'b0011;
                    3'b010: PSTRB = 4'b1111;
                    default: PSTRB = 4'b1111;
                endcase
                next_state = ENABLE;
            end

            ENABLE: begin
                PENABLE = 1'b1;  // Assert PENABLE to start APB transaction
                if (PREADY) begin
                    next_state = RESPONSE;
                end
            end

            RESPONSE: begin
                // Capture APB read data and response for the AHB interface
                HRDATA[selected_ahb] = PRDATA;
                HRESP[selected_ahb]  = PSLVERROR;
                next_state = IDLE; // Return to IDLE after response is captured
            end
        endcase
    end

    // Arbitration logic based on ARB_TYPE parameter
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            selected_ahb <= 0;
            weight_counter <= 0;
        end else begin
            case (ARB_TYPE)
                0: selected_ahb <= (selected_ahb == NUM_AHB-1) ? 0 : selected_ahb + 1;
                1: for (int i = 0; i < NUM_AHB; i++) if (HSEL[i] && HREADY[i]) selected_ahb <= i;
                2: begin
                    if (weight_counter < (selected_ahb == 0 ? WEIGHT_0 : WEIGHT_1)) begin
                        weight_counter <= weight_counter + 1;
                    end else begin
                        weight_counter <= 0;
                        selected_ahb <= (selected_ahb == 0) ? 1 : 0;
                    end
                end
                default: selected_ahb <= 0;
            endcase
        end
    end

    // Illegal access checks for each APB peripheral
    generate
        genvar i;
        for (i = 0; i < NUM_APB; i++) begin : gen_ilac_signals
            always_comb begin
                sec_ilac[i] = (PSEL[i] && HPROT[selected_ahb][3] == 1'b0);
                cid_ilac[i] = (PSEL[i] && HPROT[selected_ahb][2] != 1'b1);
                priv_ilac[i] = (PSEL[i] && HPROT[selected_ahb][1:0] != 2'b11);
            end
        end
    endgenerate

endmodule
