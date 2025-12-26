// ============================================================================
// Branch Ground Truth Storage
// Stores expected branch outcomes for verification
// Format: {valid, taken, pc[31:0], target[31:0]}
// ============================================================================
module branch_ground_truth #(
    parameter ADDR_WIDTH = 8,   // 256 branch entries
    parameter INIT_FILE = "branches.mem"
)(
    input wire clk,
    input wire [ADDR_WIDTH-1:0] lookup_addr,
    output reg valid,
    output reg [31:0] pc,
    output reg taken,
    output reg [31:0] target
);

    // Storage: {valid[0], taken[1], pc[33:2], target[65:34]}
    (* ram_style = "block" *) reg [65:0] branch_table [0:(1<<ADDR_WIDTH)-1];
    
    // Initialize from file
    initial begin
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, branch_table);
        end
    end
    
    // Lookup
    always @(posedge clk) begin
        valid  <= branch_table[lookup_addr][65];
        taken  <= branch_table[lookup_addr][64];
        pc     <= branch_table[lookup_addr][63:32];
        target <= branch_table[lookup_addr][31:0];
    end

endmodule