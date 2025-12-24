
// ============================================================================
// Prefetch Buffer
// Stores up to 8 instructions (32-bit each)
// ============================================================================
module prefetch_buffer #(
    parameter DEPTH = 8
)(
    input wire clk,
    input wire rst_n,
    
    // Write interface (from memory)
    input wire write_enable,
    input wire [31:0] write_data,
    input wire [31:0] write_pc,
    
    // Read interface (to fetch unit)
    input wire read_enable,
    output reg [31:0] read_data,
    output reg [31:0] read_pc,
    output reg valid,
    
    // Status
    output reg full,
    output reg empty,
    output reg [3:0] count,
    
    // Flush on branch misprediction
    input wire flush
);

    reg [31:0] buffer_data [0:DEPTH-1];
    reg [31:0] buffer_pc [0:DEPTH-1];
    reg [2:0] write_ptr;
    reg [2:0] read_ptr;
    
    integer i;
    
    // Status signals
    always @(*) begin
        empty = (count == 0);
        full = (count == DEPTH);
    end
    
    // Read logic
    always @(*) begin
        if (!empty && read_enable) begin
            read_data = buffer_data[read_ptr];
            read_pc = buffer_pc[read_ptr];
            valid = 1'b1;
        end else begin
            read_data = 32'h0;
            read_pc = 32'h0;
            valid = 1'b0;
        end
    end
    
    // Write and pointer management
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_ptr <= 0;
            read_ptr <= 0;
            count <= 0;
            for (i = 0; i < DEPTH; i = i + 1) begin
                buffer_data[i] <= 32'h0;
                buffer_pc[i] <= 32'h0;
            end
        end else if (flush) begin
            write_ptr <= 0;
            read_ptr <= 0;
            count <= 0;
        end else begin
            // Handle write
            if (write_enable && !full) begin
                buffer_data[write_ptr] <= write_data;
                buffer_pc[write_ptr] <= write_pc;
                write_ptr <= write_ptr + 1;
                if (!read_enable || empty)
                    count <= count + 1;
            end
            
            // Handle read
            if (read_enable && !empty) begin
                read_ptr <= read_ptr + 1;
                if (!write_enable || full)
                    count <= count - 1;
            end
        end
    end

endmodule
