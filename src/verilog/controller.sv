module controller import calculator_pkg::*;(
  	input  logic              clk_i,
    input  logic              rst_i,
  
  	// Memory Access
    input  logic [ADDR_W-1:0] read_start_addr,
    input  logic [ADDR_W-1:0] read_end_addr,
    input  logic [ADDR_W-1:0] write_start_addr,
    input  logic [ADDR_W-1:0] write_end_addr,
  
  	// Control
    output logic                      write_a,
    output logic [ADDR_W-1:0]         w_addr_a,
    output logic [DATA_W-1:0]         w_data_a,
    output logic                      write_b,
    output logic [ADDR_W-1:0]         w_addr_b,
    output logic [DATA_W-1:0]         w_data_b, 
	  output logic                      read,
    output logic [ADDR_W-1:0]         r_addr,
    input  logic [MEM_WORD_SIZE-1:0]  r_data,

  	// Buffer Control (1 = upper, 0, = lower)
    output logic              buffer_control,
	  output logic              buffer_we,
  
  	// These go into adder
  	output logic [DATA_W-1:0]       op_a,
    output logic [DATA_W-1:0]       op_b,
  
    input  logic [MEM_WORD_SIZE-1:0]       buff_result

); 
	//TODO: Write your controller state machine as you see fit. 
	//HINT: See "6.2 Two Always BLock FSM coding style" from refmaterials/1_fsm_in_systemVerilog.pdf
	// This serves as a good starting point, but you might find it more intuitive to add more than two always blocks.

	//See calculator_pkg.sv for state_t enum definition
	typedef enum logic [2:0] {
    	S_IDLE     = 3'd0,
    	S_READ1    = 3'd1,
    	S_ADD1     = 3'd2,
    	S_READ2    = 3'd3,
    	S_END      = 3'd4,
   		S_ADD2     = 3'd5,
    	S_WRITE    = 3'd6   
    } state_t;

    state_t               state, nstate;
    logic [ADDR_W-1:0]    r_ptr, w_ptr;

	//State reg, other registers as needed
	always_ff @(posedge clk_i) begin
		if (rst_i) begin
      		state <= S_IDLE;
      		r_ptr <= '0;
      		w_ptr <= '0;
    	end else begin
      		state <= nstate;
    unique case (state)
        S_IDLE: begin
          r_ptr <= read_start_addr;
          w_ptr <= write_start_addr;
        end

        S_WRITE: begin
          r_ptr <= r_ptr + 2;
          w_ptr <= w_ptr + 1;
        end
        default: ;
    endcase
    	end
  	end

	
	//Next state logic, outputs
	always_comb begin
		nstate          = state;
    	read            = 1'b0;
    	r_addr          = r_ptr;
   
    	write_a         = 1'b0; w_addr_a = w_ptr; w_data_a = '0;
    	write_b         = 1'b0; w_addr_b = w_ptr; w_data_b = '0;

    	op_a            = '0;
    	op_b            = '0;
    	buffer_control  = 1'b0;
    	buffer_we       = 1'b0;

    	unique case (state)

      		S_IDLE: begin
        		nstate = (read_start_addr > read_end_addr || write_start_addr > write_end_addr)
            		? S_IDLE : S_READ1;
      		end

      S_READ1: begin
        read   = 1'b1;
        r_addr = r_ptr;
        nstate = S_ADD1;
      end

      S_ADD1: begin
        read   = 1'b0;
        r_addr = r_ptr;

        op_a = r_data[31:0];
        op_b = r_data[63:32];
        buffer_control = 1'b0;
        buffer_we      = 1'b1;
        nstate         = S_READ2;
      end

      S_READ2: begin
        read   = 1'b1;
        r_addr = r_ptr + 1;
        nstate = S_ADD2;
      end

      S_ADD2: begin
        read   = 1'b0;
        r_addr = r_ptr + 1'b1;

        op_a = r_data[31:0];
        op_b = r_data[63:32];
        buffer_control = 1'b1;
        buffer_we      = 1'b1;
        nstate         = S_WRITE;
      end

      S_WRITE: begin
        write_a  = 1'b1;
        w_addr_a = w_ptr;
        w_data_a = buff_result[DATA_W-1:0];
        write_b  = 1'b1;
        w_addr_b = w_ptr;
        w_data_b = buff_result[MEM_WORD_SIZE-1:DATA_W];

        nstate = (w_ptr >= write_end_addr) ? S_END : S_READ1;
      end

      S_END: begin
        nstate = S_END;      
      end

      default: nstate = S_IDLE;
    endcase
  end

endmodule