/*
 * Functional coverage model for the calculator DUT.
 * Instantiated in calc_tb_top and connected to DUT signals. Each covergroup maps
 * to a section of the test plan:
 *   cg_config   - window configuration of every calculation that starts
 *   cg_legality - legal/illegal read & write window combinations seen in S_IDLE
 *   cg_datapath - adder operand corners and carry-out, per result half
 *   cg_fsm      - spec-level FSM sequences (start, LSB/MSB pipeline, next word, done)
 *   cg_reset    - FSM state at the moment reset is asserted
 */
module calc_coverage import calculator_pkg::*; (
  input logic              clk,
  input logic              rst,
  input state_t            state,
  input logic [ADDR_W-1:0] rd_start,
  input logic [ADDR_W-1:0] rd_end,
  input logic [ADDR_W-1:0] wr_start,
  input logic [ADDR_W-1:0] wr_end,
  input logic              buffer_we,
  input logic              buffer_loc,   // 0 = lower half (LSB), 1 = upper half (MSB)
  input logic [DATA_W-1:0] op_a,
  input logic [DATA_W-1:0] op_b
);

  localparam int ADDR_MAX = (1 << ADDR_W) - 1;

  // Previous-cycle values, used to detect the start of a calculation and the rising edge of reset
  state_t prev_state;
  logic   prev_rst;
  always_ff @(posedge clk) begin
    prev_state <= state;
    prev_rst   <= rst;
  end

  logic calc_start;
  assign calc_start = (prev_state == S_IDLE) && (state == S_READ1);

  // Window lengths (one extra bit so a full 512-entry window does not overflow)
  logic [ADDR_W:0] rd_len, wr_len;
  assign rd_len = rd_end - rd_start + 1'b1;
  assign wr_len = wr_end - wr_start + 1'b1;

  // Each result word consumes two read addresses
  typedef enum logic [1:0] {RD_SHORT, RD_MATCHED, RD_LONG} rd_ratio_t;
  rd_ratio_t rd_ratio;
  always_comb begin
    if      (rd_len <  2 * wr_len) rd_ratio = RD_SHORT;
    else if (rd_len == 2 * wr_len) rd_ratio = RD_MATCHED;
    else                           rd_ratio = RD_LONG;
  end

  // Placement of the write window relative to the read window
  typedef enum logic [1:0] {WR_IN_PLACE, WR_DISJOINT, WR_OVERLAP} wr_place_t;
  wr_place_t wr_place;
  always_comb begin
    if (wr_start == rd_start)                       wr_place = WR_IN_PLACE;
    else if (wr_end < rd_start || wr_start > rd_end) wr_place = WR_DISJOINT;
    else                                             wr_place = WR_OVERLAP;
  end

  // 33-bit sum to observe the carry out of the 32-bit adder
  logic [DATA_W:0] full_sum;
  logic            carry_out;
  assign full_sum  = {1'b0, op_a} + {1'b0, op_b};
  assign carry_out = full_sum[DATA_W];

  // ---------------------------------------------------------------------------
  // Window configuration, sampled once when a calculation starts (S_IDLE -> S_READ1)
  // ---------------------------------------------------------------------------
  covergroup cg_config @(posedge clk iff (!rst && calc_start));
    option.per_instance = 1;

    cp_rd_start: coverpoint rd_start {
      bins zero = {0};
      bins low  = {[1 : ADDR_MAX/2]};
      bins high = {[ADDR_MAX/2 + 1 : ADDR_MAX]};
    }
    cp_rd_end_at_top: coverpoint (&rd_end) {
      bins top   = {1'b1};
      bins below = {1'b0};
    }
    cp_rd_len: coverpoint rd_len {
      bins two   = {2};
      bins short = {[3 : 8]};
      bins long  = {[9 : $]};
    }
    cp_wr_len: coverpoint wr_len {
      bins one   = {1};
      bins two   = {2};
      bins short = {[3 : 4]};
      bins long  = {[5 : $]};
    }
    cp_rd_ratio: coverpoint rd_ratio {
      bins short   = {RD_SHORT};    // read window smaller than 2x write window
      bins matched = {RD_MATCHED};
      bins long    = {RD_LONG};
    }
    cp_wr_place: coverpoint wr_place {
      bins in_place = {WR_IN_PLACE};
      bins disjoint = {WR_DISJOINT};
      bins overlap  = {WR_OVERLAP};
    }

    cx_wr_len_place: cross cp_wr_len, cp_wr_place;
  endgroup

  // ---------------------------------------------------------------------------
  // Window legality, sampled every cycle the FSM waits in S_IDLE
  // ---------------------------------------------------------------------------
  covergroup cg_legality @(posedge clk iff (!rst && state == S_IDLE));
    option.per_instance = 1;

    cp_rd_illegal: coverpoint (rd_start > rd_end) {
      bins legal   = {1'b0};
      bins illegal = {1'b1};
    }
    cp_wr_illegal: coverpoint (wr_start > wr_end) {
      bins legal   = {1'b0};
      bins illegal = {1'b1};
    }

    cx_legality: cross cp_rd_illegal, cp_wr_illegal;
  endgroup

  // ---------------------------------------------------------------------------
  // Adder operands, sampled whenever a result half is written into the buffer
  // ---------------------------------------------------------------------------
  covergroup cg_datapath @(posedge clk iff (!rst && buffer_we));
    option.per_instance = 1;

    cp_op_a: coverpoint op_a {
      bins zero  = {0};
      bins mid_lo = {[1 : 32'h0000_FFFF]};
      bins mid_hi = {[32'h0001_0000 : 32'hFFFF_FFFE]};
      bins max   = {32'hFFFF_FFFF};
    }
    cp_op_b: coverpoint op_b {
      bins zero  = {0};
      bins mid_lo = {[1 : 32'h0000_FFFF]};
      bins mid_hi = {[32'h0001_0000 : 32'hFFFF_FFFE]};
      bins max   = {32'hFFFF_FFFF};
    }
    cp_carry: coverpoint carry_out {
      bins no_carry = {1'b0};
      bins carry    = {1'b1};   // result truncated to 32 bits
    }
    cp_half: coverpoint buffer_loc {
      bins lsb = {1'b0};
      bins msb = {1'b1};
    }

    cx_operands:   cross cp_op_a, cp_op_b;
    cx_carry_half: cross cp_carry, cp_half;
  endgroup

  // ---------------------------------------------------------------------------
  // FSM sequences required by the spec
  // ---------------------------------------------------------------------------
  covergroup cg_fsm @(posedge clk iff (!rst));
    option.per_instance = 1;

    cp_seq: coverpoint state {
      bins go        = (S_IDLE  => S_READ1);
      bins one_word  = (S_READ1 => S_ADD1 => S_READ2 => S_ADD2 => S_WRITE);
      bins next_word = (S_WRITE => S_READ1);
      bins done      = (S_WRITE => S_END);
      bins hold_idle = (S_IDLE  => S_IDLE);   // illegal window keeps the FSM in S_IDLE
      bins hold_end  = (S_END   => S_END);
    }
  endgroup

  // ---------------------------------------------------------------------------
  // FSM state when reset is asserted (rising edge of reset)
  // ---------------------------------------------------------------------------
  covergroup cg_reset @(posedge clk iff (rst && !prev_rst));
    option.per_instance = 1;

    cp_reset_in_state: coverpoint state {
      bins in_idle  = {S_IDLE};
      bins in_read1 = {S_READ1};
      bins in_add1  = {S_ADD1};
      bins in_read2 = {S_READ2};
      bins in_add2  = {S_ADD2};
      bins in_write = {S_WRITE};
      bins in_end   = {S_END};
    }
  endgroup

  cg_config   u_cg_config   = new();
  cg_legality u_cg_legality = new();
  cg_datapath u_cg_datapath = new();
  cg_fsm      u_cg_fsm      = new();
  cg_reset    u_cg_reset    = new();

  final begin
    $display("==================== FUNCTIONAL COVERAGE ====================");
    $display("  cg_config   : %6.2f%%", u_cg_config.get_inst_coverage());
    $display("  cg_legality : %6.2f%%", u_cg_legality.get_inst_coverage());
    $display("  cg_datapath : %6.2f%%", u_cg_datapath.get_inst_coverage());
    $display("  cg_fsm      : %6.2f%%", u_cg_fsm.get_inst_coverage());
    $display("  cg_reset    : %6.2f%%", u_cg_reset.get_inst_coverage());
    $display("=============================================================");
  end

endmodule
