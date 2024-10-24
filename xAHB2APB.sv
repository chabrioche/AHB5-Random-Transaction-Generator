module xAHB2APB #(
    parameter int NUM_AHB = 2,         // Number of AHB interfaces
    parameter int NUM_APB = 4,         // Number of APB peripherals
    parameter int ARB_TYPE = 0,        // Arbitration type: 0 = round-robin, 1 = fixed-priority, 2 = weighted round-robin, 3 = dynamic priority, 4 = token-based
    parameter int WEIGHT_0 = 1,        // Weight for AHB interface 0 (for weighted round-robin)
    parameter int WEIGHT_1 = 1         // Weight for AHB interface 1 (for weighted round-robin)
)(
    input  logic        HCLK,          // AHB clock signal
    input  logic        HRESETn,       // Active-low reset signal for AHB
    input  logic [31:0] HADDR     [NUM_AHB-1:0],   // AHB address signals from multiple interfaces
    input  logic [31:0] HWDATA    [NUM_AHB-1:0],   // AHB write data signals from multiple interfaces
    input  logic        HWRITE    [NUM_AHB-1:0],   // AHB write enable signals from multiple interfaces
    input  logic [2:0]  HSIZE     [NUM_AHB-1:0],   // AHB transfer size signals from multiple interfaces
    input  logic [2:0]  HBURST    [NUM_AHB-1:0],   // AHB burst type signals from multiple interfaces
    input  logic [3:0]  HPROT     [NUM_AHB-1:0],   // AHB protection control signals from multiple interfaces
    input  logic [1:0]  HTRANS    [NUM_AHB-1:0],   // AHB transfer type signals from multiple interfaces
    input  logic        HSEL      [NUM_AHB-1:0],   // AHB select signals from multiple interfaces
    input  logic        HREADY    [NUM_AHB-1:0],   // AHB ready signals from multiple interfaces
    input  logic        HMASTLOCK [NUM_AHB-1:0],   // AHB master lock signals (AHB5)
    input  logic        HNONSEC   [NUM_AHB-1:0],   // AHB Non-Secure signals (AHB5)
    input  logic [3:0]  HCID      [NUM_AHB-1:0],   // AHB Compartment ID (AHB5)
    output logic [31:0] HRDATA    [NUM_AHB-1:0],   // AHB read data signals to multiple interfaces
    output logic        HRESP     [NUM_AHB-1:0],   // AHB response signals to multiple interfaces

    // APB4 interface
    output logic [31:0] PADDR,     // APB address
    output logic [31:0] PWDATA,    // APB write data
    output logic        PWRITE,    // APB write enable
    output logic        PSEL,      // APB select
    output logic        PENABLE,   // APB enable
    output logic [3:0]  PSTRB,     // APB write strobe (APB4)
    input  logic [31:0] PRDATA,    // APB read data
    input  logic        PSLVERROR, // APB slave error (APB4)
    input  logic        PREADY,    // APB ready signal (APB4)

    // Illegal access detection outputs for each APB peripheral
    output logic [NUM_APB-1:0] sec_ilac,   // Illegal secure access signal for each APB peripheral
    output logic [NUM_APB-1:0] cid_ilac,   // Illegal compartment ID access signal for each APB peripheral
    output logic [NUM_APB-1:0] priv_ilac   // Illegal privilege access signal for each APB peripheral
);

    logic [$clog2(NUM_AHB)-1:0] selected_ahb;  // Selected AHB interface (log2 based on NUM_AHB)
    logic arb_enable;

    // Expected attributes for each APB peripheral (for checking against AHB transaction)
    logic [NUM_APB-1:0] apb_secure;  // Security attribute (1 = secure, 0 = non-secure)
    logic [3:0] apb_cid [NUM_APB-1:0];  // Expected compartment ID for each APB peripheral
    logic [3:0] apb_priv [NUM_APB-1:0]; // Expected privilege level for each APB peripheral

    // Arbitration logic based on ARB_TYPE parameter
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            selected_ahb <= 0;  // Start by selecting AHB interface 0
            arb_enable   <= 1'b0;
        end else begin
            case (ARB_TYPE)
                // Round-Robin Arbitration
                0: begin
                    if (HSEL[selected_ahb] && HREADY[selected_ahb]) begin
                        selected_ahb <= selected_ahb;
                    end else begin
                        if (selected_ahb == NUM_AHB-1) begin
                            selected_ahb <= 0;
                        end else begin
                            selected_ahb <= selected_ahb + 1;
                        end
                    end
                end

                // Fixed-Priority Arbitration
                1: begin
                    for (int i = 0; i < NUM_AHB; i++) begin
                        if (HSEL[i] && HREADY[i]) begin
                            selected_ahb <= i;
                            break;
                        end
                    end
                end

                // Weighted Round-Robin Arbitration
                2: begin
                    if (priority_counter < WEIGHT_0 && selected_ahb == 0) begin
                        if (HSEL[0] && HREADY[0]) begin
                            selected_ahb <= 0;
                            priority_counter <= priority_counter + 1;
                        end
                    end else if (priority_counter < WEIGHT_1 && selected_ahb == 1) begin
                        if (HSEL[1] && HREADY[1]) begin
                            selected_ahb <= 1;
                            priority_counter <= priority_counter + 1;
                        end
                    end else begin
                        priority_counter <= 0;
                        if (selected_ahb == 0) selected_ahb <= 1;
                        else selected_ahb <= 0;
                    end
                end

                // Dynamic Priority Arbitration
                3: begin
                    if (priority_counter < 4) begin
                        if (HSEL[selected_ahb] && HREADY[selected_ahb]) begin
                            priority_counter <= priority_counter + 1;
                        end else begin
                            if (selected_ahb == NUM_AHB-1) selected_ahb <= 0;
                            else selected_ahb <= selected_ahb + 1;
                            priority_counter <= 0;
                        end
                    end else begin
                        priority_counter <= 0;
                        if (selected_ahb == NUM_AHB-1) selected_ahb <= 0;
                        else selected_ahb <= selected_ahb + 1;
                    end
                end

                // Token-Based Arbitration
                4: begin
                    if (HSEL[selected_ahb] && HREADY[selected_ahb]) begin
                        selected_ahb <= selected_ahb;
                    end else begin
                        if (selected_ahb == NUM_AHB-1) selected_ahb <= 0;
                        else selected_ahb <= selected_ahb + 1;
                    end
                end

                default: selected_ahb <= 0;  // Default to AHB interface 0
            endcase
        end
    end

    // Forward the selected AHB signals to the APB interface
    always_comb begin
        PADDR   = HADDR[selected_ahb];
        PWDATA  = HWDATA[selected_ahb];
        PWRITE  = HWRITE[selected_ahb];
        PSEL    = HSEL[selected_ahb];
        PENABLE = HREADY[selected_ahb];

        // Set PSTRB for APB4 based on HSIZE
        case (HSIZE[selected_ahb])
            3'b000: PSTRB = 4'b0001; // Byte (8-bit)
            3'b001: PSTRB = 4'b0011; // Halfword (16-bit)
            3'b010: PSTRB = 4'b1111; // Word (32-bit)
            default: PSTRB = 4'b1111; // Default to 32-bit word access
        endcase
    end

    // Illegal access checks for each APB peripheral
    generate
        genvar i;
        for (i = 0; i < NUM_APB; i++) begin : gen_ilac_signals
            always_comb begin
                // Check for illegal secure access (if a non-secure transaction tries to access a secure peripheral)
                if (apb_secure[i] && HNONSEC[selected_ahb]) begin
                    sec_ilac[i] = 1'b1;
                end else begin
                    sec_ilac[i] = 1'b0;
                end

                // Check for illegal compartment ID access (if the HCID doesn't match the expected CID)
                if (HCID[selected_ahb] != apb_cid[i]) begin
                    cid_ilac[i] = 1'b1;
                end else begin
                    cid_ilac[i] = 1'b0;
                end

                // Check for illegal privilege access (if the HPROT privilege level doesn't match)
                if (HPROT[selected_ahb][2:1] != apb_priv[i]) begin
                    priv_ilac[i] = 1'b1;
                end else begin
                    priv_ilac[i] = 1'b0;
                end
            end
        end
    endgenerate

    // Return the APB read data and response to the selected AHB interface
    generate
        genvar j;
        for (j = 0; j < NUM_AHB; j++) begin : gen_ahb_response
            always_ff @(posedge HCLK or negedge HRESETn) begin
                if (!HRESETn) begin
                    HRDATA[j] <= 32'd0;
                    HRESP[j]  <= 1'b0;
                end else begin
                    if (j == selected_ahb) begin
                        HRDATA[j] <= PRDATA;
                        HRESP[j]  <= PSLVERROR;
                    end else begin
                        HRDATA[j] <= 32'd0;
                        HRESP[j]  <= 1'b0;
                    end
                end
            end
        end
    endgenerate

endmodule
