class calc_sequencer #(int DataSize, int AddrSize);

  typedef logic [AddrSize-1:0] addr_t;

  mailbox #(calc_seq_item #(DataSize, AddrSize)) calc_box;

  function new();
    calc_box = new();
  endfunction : new

task gen(int num,
           logic [AddrSize-1:0] lo = 'h00,
           logic [AddrSize-1:0] hi = 'hFE);
    repeat (num) begin
      calc_seq_item#(DataSize, AddrSize) tr = new();
      if (!tr.randomize() with {
            read_start_addr inside {[lo:hi]};
            (read_start_addr + addr_t'(1)) inside {[lo:hi]};
            read_end_addr == (read_start_addr + addr_t'(1));
            write_start_addr == read_start_addr;
            write_end_addr   == write_start_addr;
          }) begin
        $error("sequencer: randomize() failed");
      end
      calc_box.put(tr);
    end
  endtask : gen

  task gen_varwin(int num,
                  int unsigned min_len = 2,
                  int unsigned max_len = 4,
                  logic [AddrSize-1:0] lo = 'h00,
                  logic [AddrSize-1:0] hi = 'hFE);
    if (min_len < 2) min_len = 2;
    if (max_len < min_len) max_len = min_len;

    repeat (num) begin
      calc_seq_item#(DataSize, AddrSize) tr = new();
      int unsigned len;
      if (!std::randomize(len) with { len inside {[min_len:max_len]}; }) begin
        $error("sequencer: std::randomize(len) failed");
      end
      if (!tr.randomize() with {
          read_start_addr inside {[lo:hi]};
          (read_start_addr + addr_t'(len-1)) inside {[lo:hi]};
          read_end_addr == (read_start_addr + addr_t'(len-1));
          write_start_addr == read_start_addr;
          write_end_addr   == write_start_addr;
        }) begin
        $error("sequencer: randomize() with variable window failed");
      end
      calc_box.put(tr);
    end
  endtask : gen_varwin

  // Coverage-closure sequence: write window of 1..max_wr_len words, read window sized
  // 2x the write window (optionally over-provisioned), placed anywhere in the full
  // address range, with the write window in place, trailing by one, or disjoint.
  task gen_cov(int num, int unsigned max_wr_len = 8);
    int unsigned amax = (1 << AddrSize) - 1;

    repeat (num) begin
      calc_seq_item#(DataSize, AddrSize) tr = new();
      int unsigned len, extra, wmode, amode;
      if (!std::randomize(len, extra, wmode, amode) with {
            len   inside {[1:max_wr_len]};
            extra dist {0 := 8, [1:4] :/ 2};       // ~20% over-provisioned read windows
            wmode dist {0 := 4, 1 := 2, 2 := 4};   // 0: in place, 1: trailing by one, 2: disjoint
            amode dist {0 := 8, 1 := 1, 2 := 1};   // 0: anywhere, 1: bottom of memory, 2: top of memory
          }) begin
        $error("sequencer: std::randomize(len, extra, wmode, amode) failed");
      end
      if (!tr.randomize() with {
            int'(read_start_addr) <= amax - (2*len - 1 + extra);
            int'(read_end_addr)   == int'(read_start_addr) + 2*len - 1 + extra;
            (amode == 1) -> read_start_addr == 0;
            (amode == 2) -> int'(read_end_addr) == amax;

            int'(write_end_addr) == int'(write_start_addr) + len - 1;
            int'(write_end_addr) <= amax;
            (wmode == 0) -> write_start_addr == read_start_addr;
            (wmode == 1) -> int'(write_start_addr) == int'(read_start_addr) + 1;
            (wmode == 2) -> (int'(write_end_addr) < int'(read_start_addr)) ||
                            (int'(write_start_addr) > int'(read_end_addr));
          }) begin
        $error("sequencer: randomize() for coverage closure failed");
      end
      calc_box.put(tr);
    end
  endtask : gen_cov

endclass : calc_sequencer
