module xAHB2APB #(
    parameter int NUM_AHB = 2,         // Number of AHB interfaces
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
    output logic [31:0] HRDATA    [NUM_AHB-1:0],   // AHB read data signals to multiple interfaces
    output logic        HRESP     [NUM_AHB-1:0],   // AHB response signals to multiple interfaces

    // APB interface
    output logic [31:0] PADDR,     // APB address
    output logic [31:0] PWDATA,    // APB write data
    output logic        PWRITE,    // APB write enable
    output logic        PSEL,      // APB select
    output logic        PENABLE,   // APB enable
    input  logic [31:0] PRDATA,    // APB read data
    input  logic        PSLVERROR, // APB slave error
    input  logic        PREADY     // APB ready signal
);

    logic [$clog2(NUM_AHB)-1:0] selected_ahb;  // Selected AHB interface (log2 based on NUM_AHB)
    logic arb_enable;
    int   priority_counter = 0;   // Used for weighted round-robin and dynamic priority

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

                // Dynamic Priority Arbitration (simplified, based on number of transactions)
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
    end

    // Return the APB read data and response to the selected AHB interface
    generate
        genvar i;
        for (i = 0; i < NUM_AHB; i++) begin : gen_ahb_response
            always_ff @(posedge HCLK or negedge HRESETn) begin
                if (!HRESETn) begin
                    HRDATA[i] <= 32'd0;
                    HRESP[i]  <= 1'b0;
                end else begin
                    if (i == selected_ahb) begin
                        HRDATA[i] <= PRDATA;
                        HRESP[i]  <= PSLVERROR;
                    end else begin
                        HRDATA[i] <= 32'd0;
                        HRESP[i]  <= 1'b0;
                    end
                end
            end
        end
    endgenerate

endmodule
