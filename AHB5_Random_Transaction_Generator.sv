module AHB5_Random_Transaction_Generator #(
    parameter int NUM_AHB = 2 // Number of AHB interfaces (default: 2)
)(
    input  logic        HCLK,         // AHB clock signal
    input  logic        HRESETn,      // Active-low reset signal for AHB
    output logic [31:0] HADDR     [NUM_AHB-1:0],   // AHB address signals
    output logic [31:0] HWDATA    [NUM_AHB-1:0],   // AHB write data signals
    output logic        HWRITE    [NUM_AHB-1:0],   // AHB write enable signals
    output logic [2:0]  HSIZE     [NUM_AHB-1:0],   // AHB transfer size signals
    output logic [2:0]  HBURST    [NUM_AHB-1:0],   // AHB burst type signals
    output logic [3:0]  HPROT     [NUM_AHB-1:0],   // AHB protection control signals
    output logic [1:0]  HTRANS    [NUM_AHB-1:0],   // AHB transfer type signals
    output logic        HSEL      [NUM_AHB-1:0],   // AHB select signals
    input  logic        HREADY    [NUM_AHB-1:0],   // AHB ready signals
    input  logic [31:0] HRDATA    [NUM_AHB-1:0],   // AHB read data signals
    input  logic        HRESP     [NUM_AHB-1:0],   // AHB response signals
    output logic [31:0] RDATA_OUT [NUM_AHB-1:0],   // Output for read data for each interface
    output logic        RESP_OUT  [NUM_AHB-1:0]    // Output for response signal for each interface
);

    // LFSR instances for generating pseudo-random values
    logic [31:0] lfsr_addr, lfsr_data, lfsr_ctrl, lfsr_sel;
    
    // Instantiate LFSRs: one for address, one for write data, one for control, and one for interface selection
    LFSR lfsr1(.clk(HCLK), .rstn(HRESETn), .random_val(lfsr_addr));    // LFSR for generating address
    LFSR lfsr2(.clk(HCLK), .rstn(HRESETn), .random_val(lfsr_data));    // LFSR for generating write data
    LFSR lfsr3(.clk(HCLK), .rstn(HRESETn), .random_val(lfsr_ctrl));    // LFSR for generating control signals
    LFSR lfsr4(.clk(HCLK), .rstn(HRESETn), .random_val(lfsr_sel));     // LFSR for selecting AHB interface

    // Generate logic for handling each AHB interface
    genvar i;
    generate
        for (i = 0; i < NUM_AHB; i++) begin : gen_ahb_interface
            always_ff @(posedge HCLK or negedge HRESETn) begin
                if (!HRESETn) begin
                    // Reset all signals for each AHB interface
                    HADDR[i]    <= 32'd0;
                    HWDATA[i]   <= 32'd0;
                    HWRITE[i]   <= 1'b0;
                    HSIZE[i]    <= 3'b000;
                    HBURST[i]   <= 3'b000;
                    HPROT[i]    <= 4'b0000;
                    HTRANS[i]   <= 2'b00;
                    HSEL[i]     <= 1'b0;               // Reset HSEL
                    RDATA_OUT[i] <= 32'd0;
                    RESP_OUT[i]  <= 1'b0;
                end else begin
                    if (lfsr_sel % NUM_AHB == i && HREADY[i]) begin
                        // When the selected AHB interface is ready, generate a transaction
                        HADDR[i]   <= (lfsr_addr & 32'hFFFF_FFFF);  // Generate a random address
                        HWDATA[i]  <= lfsr_data;                    // Generate random write data
                        HWRITE[i]  <= lfsr_ctrl[0];                 // Randomize between read/write
                        HSIZE[i]   <= lfsr_ctrl[2:0];               // Randomize transfer size
                        HBURST[i]  <= lfsr_ctrl[5:3];               // Randomize burst type
                        HPROT[i]   <= lfsr_ctrl[9:6];               // Randomize protection control
                        HTRANS[i]  <= lfsr_ctrl[11:10];             // Randomize transfer type
                        HSEL[i]    <= 1'b1;                         // Assert HSEL for the selected interface
                    end else begin
                        HSEL[i] <= 1'b0;                            // Deassert HSEL for non-selected interfaces
                    end
                    // Capture the response and read data from the interface
                    RDATA_OUT[i] <= HRDATA[i];                      // Capture read data
                    RESP_OUT[i]  <= HRESP[i];                       // Capture response signal
                end
            end
        end
    endgenerate

endmodule
