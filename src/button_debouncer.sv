// ============================================================================
// Simple Button Debouncer
// ============================================================================
module button_debouncer #(
    parameter DEBOUNCE_TIME = 1000000  // 10ms at 100MHz
)(
    input wire clk,
    input wire rst_n,
    input wire button_in,
    output reg button_out
);

    reg [19:0] counter;
    reg button_sync_0, button_sync_1;
    
    // Synchronizer
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            button_sync_0 <= 1'b0;
            button_sync_1 <= 1'b0;
        end else begin
            button_sync_0 <= button_in;
            button_sync_1 <= button_sync_0;
        end
    end
    
    // Debouncer
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 0;
            button_out <= 1'b0;
        end else begin
            if (button_sync_1 == button_out) begin
                counter <= 0;
            end else begin
                counter <= counter + 1;
                if (counter == DEBOUNCE_TIME) begin
                    button_out <= button_sync_1;
                    counter <= 0;
                end
            end
        end
    end

endmodule