// ------------------------------------------------------------------------------
// Define UVM testbench package.

package vscale_mul_div_unit_pkg;

   // Import UVM packages.
   import uvm_pkg::*;

   // ----------------------------------------
   // I don't need to extend the sequencer.  Typedef will do.

   typedef uvm_sequencer #(input_transaction) input_sequencer;

endpackage : vscale_mul_div_unit_pkg