/*
 * This package defines common parameters used across various modules in the design to ensure consistency and ease of maintenance. 
 * It includes parameters for data width, memory word size, and address width (defined by size of SRAM).
 */
package calculator_pkg;
    //parameter for size of data
    parameter DATA_W = 32;

    //parameter for size of memory word
    parameter MEM_WORD_SIZE = 64;

    parameter ADDR_W = 9;

    typedef enum logic [2:0] {S_IDLE,S_READ,S_ADD,S_WRITE,S_END} state_t;
    typedef enum logic {LOWER, UPPER} buffer_loc_t;

endpackage