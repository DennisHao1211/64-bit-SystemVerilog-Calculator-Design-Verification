interface calc_if #(int DataSize, int AddrSize) (input wire clk);
  // All relevant signals that the testbench needs to properly test the DUT.

  // Write enable for SRAM
  logic wr_en;

  // Read enable for SRAM
  logic rd_en;

  // When the controller is ready to start a new calculation
  logic ready;

  // Used to select between SRAM A and B, 0 is for A, 1 is for B
  logic loc_sel;

  // Used to indicate that SRAM is being written to by the testbench by directly
  // writing to the memory array as opposed to using the write port
  logic initialize;

  // Active-high reset
  logic reset = 0;

  // SRAM address used specifically for writing by testbench
  logic [AddrSize-1:0] initialize_addr;

  // SRAM data used specifically for writing by testbench
  logic [DataSize-1:0] initialize_data;

  // SRAM selection between A and B specifically for writing by testbench
  logic initialize_loc_sel;

  // The data being written to SRAM by the calculator
  logic [DataSize*2-1:0] wr_data;

  // Input to DUT for the read start address
  logic [AddrSize-1:0] read_start_addr;

  // Input to DUT for the read end address
  logic [AddrSize-1:0] read_end_addr;

  // Input to DUT for the write start address
  logic [AddrSize-1:0] write_start_addr;

  // Input to DUT for the write end address
  logic [AddrSize-1:0] write_end_addr;

  // Data being read from SRAM by the calculator
  logic [DataSize*2-1:0] rd_data;

  // The current write address to SRAM for the calculator
  logic [AddrSize-1:0] curr_wr_addr;

  // The current read address from SRAM for the calculator
  logic [AddrSize-1:0] curr_rd_addr;

// Clocking block used to sample signals at a clocking event
// Input signals are sampled by one step of the global time precision which
// is 1 ns by default, so input signals are sampled 1 ns before the rising clock
// edge.
// Output signals are sampled by two time units after the rising clock edge, and
// the default time unit is 1 ns, so output signals are sampled 2 ns after the
// rising clock edge.
clocking cb @(posedge clk);
  default input #1step output #2;
`ifdef VCS
  inout ready, rd_data, wr_en, rd_en, wr_data, curr_rd_addr, curr_wr_addr, loc_sel, reset, read_start_addr, read_end_addr, write_start_addr, write_end_addr, initialize, initialize_addr, initialize_data, initialize_loc_sel;
`endif
`ifdef CADENCE
  input ready, rd_data, wr_en, rd_en, wr_data, curr_rd_addr, curr_wr_addr, loc_sel;
  output reset;
  inout read_start_addr, read_end_addr, write_start_addr, write_end_addr, initialize, initialize_addr, initialize_data, initialize_loc_sel;
`endif
endclocking

// This modport is used to restrict the interface signals to those directly relevant to the DUT
modport calc(
  input reset, wr_en, rd_en, wr_data, read_start_addr, read_end_addr, write_start_addr, write_end_addr, curr_rd_addr, curr_wr_addr, loc_sel,
  output ready, rd_data
);

endinterface
