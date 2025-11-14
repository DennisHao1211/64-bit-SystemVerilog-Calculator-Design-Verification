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

endclass : calc_sequencer
