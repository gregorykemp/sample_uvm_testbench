// ------------------------------------------------------------------------------
// Define UVM testbench package.

// Import UVM packages.
import uvm_pkg::*;

package vscale_mul_div_pkg;

   // Include UVM macros 
   `include "uvm_macros.svh"

   // Include testbench commons
   `include "my_config.svh"

   // Include agents/input
   `include "agents/input/input_transaction.svh"
   `include "agents/input/input_sequence_base.svh"
   `include "agents/input/input_sequence_long.svh"
   `include "agents/input/input_driver.svh"
   `include "agents/input/input_monitor.svh"
   `include "agents/input/input_sequencer.svh"
   `include "agents/input/input_agent.svh"
      
   // 
endpackage : vscale_mul_div_pkg