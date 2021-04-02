// ------------------------------------------------------------------------------
//
// Top module for vscale mul-div unit.
// Demonstrator for UVM application to unit-level testing.
//
// (c) 2016 Gregory A. Kemp
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// 
// ------------------------------------------------------------------------------

// Source UVM libraries.
`include "uvm_macros.svh"

// Source design defined values for more readable code.
`include "vscale_md_constants.vh"
`include "vscale_ctrl_constants.vh"
`include "rv32_opcodes.vh"

// FIXME Do I need to include the design too?  Doesn't seem right.
// May be an artifact of EDA Playground.
`include "vscale_mul_div.v"

// ------------------------------------------------------------------------------
// Define UVM testbench package.

package vscale_mul_div_unit;

   // This is a computed value based on defined value XPR_LEN.
   // It's used to constrain operand values.
   localparam XPR_LEN_MAXINT = (2 ** `XPR_LEN) - 1;


   // Import UVM packages.
   import uvm_pkg::*;

   // ----------------------------------------
   // Wrapper object for test configuration.

   class my_config extends uvm_object;

      int num_tx;

   endclass : my_config

   // ----------------------------------------
   // Define a transaction for inputs to the unit.

   class input_transaction extends uvm_sequence_item;

      // Register with object factory.
      `uvm_object_utils(input_transaction)

      // Fields we'll be randomizing in this object.
      // FIXME : there's a lot of redundancy between op1 and op2.  Would it 
      // make since to make a subclass for operands?  Leave this for now
      // as a possible future enhancement.

      // Are the operands signed or unsigned?
      rand bit op1_signedp;
      rand bit op2_signedp;
      // Signs of the operands?
      rand bit op1_sign;
      rand bit op2_sign;
      // Opcode
      rand logic [`MD_OP_WIDTH-1:0] opcode;
      // Output mux control.
      rand logic [`MD_OUT_SEL_WIDTH-1:0] mux_select;
      // Next two signals are the operands.
      rand logic [`XPR_LEN-1:0] op1;
      rand logic [`XPR_LEN-1:0] op2;

      // generation constraints

      // Really need to know if this is signed before we sweat the sign itself.
      constraint c_sign_order_op1 { solve op1_signedp before op1_sign; };
      constraint c_sign_order_op2 { solve op2_signedp before op2_sign; };

      // Need to keep both operands signed or unsigned.  Don't mix and match.
      constraint c_signed_ops_1 { solve op1_signedp before op2_signedp; };
      constraint c_signed_ops_2 { op2_signedp == op1_signedp;           };

      // We want to ensure values 0, 1, 2, -1, and -2 occur more often than
      // statistically expected.  0 and 1 are "magic" values in multiplication
      // and division.  2 simply shifts by one bit.  Distributions add up to 
      // 100% because that's how I like it.  Constraints are soft in case a
      // sequence wants to override the value later.
      constraint c_op1_value { soft op1 dist { 0 := 5, 1 := 5, 2 := 5, [3:XPR_LEN_MAXINT] := 85 }; };
      constraint c_op2_value { soft op2 dist { 0 := 5, 1 := 5, 2 := 5, [3:XPR_LEN_MAXINT] := 85 }; };

      // Now make the sign consistent with the value.
      constraint c_op1_sign { op1_signedp -> op1_sign == op1[`XPR_LEN-1]; };
      constraint c_op2_sign { op2_signedp -> op2_sign == op2[`XPR_LEN-1]; };

      // Require the opcode to be a legal value.
      constraint c_opcode_legal { opcode inside { `MD_OP_MUL, `MD_OP_DIV, `MD_OP_REM }; };

      // Constraints on rounding mode.
      constraint c_mux_select_1 { solve opcode before mux_select; };
      constraint c_mux_select_2 { if (opcode == `MD_OP_REM) (mux_select == `MD_OUT_REM); }; 
      constraint c_mux_select_3 { if (opcode != `MD_OP_REM) (mux_select != `MD_OUT_REM); }; 

      // class constructor.
      function new (string name ="");
         super.new(name);
      endfunction

      // This function dumps the whole contents of the object.  Expected use is
      // debugging and extended error reporting.
      function void print_full();
         $write("Input transaction:\n");
         $write("   Opcode: ");
         case (opcode)
            `MD_OP_MUL: $write("MD_OP_MUL");
            `MD_OP_DIV: $write("MD_OP_DIV");
            `MD_OP_REM: $write("MD_OP_REM");
            default:    $write("unknown  ");
         endcase
         $write("   Rounding mode: ");
         case (mux_select)
            `MD_OUT_LO:  $write("LO ");
            `MD_OUT_HI:  $write("HI ");
            `MD_OUT_REM: $write("REM");
         endcase
         $write("\n");
         $write("   Operand 1: ");
         if(op1_signedp) begin
            $write("  signed");
            if(op1_sign)
               $write(" - ");
            else
               $write(" + ");
         end
         $write("%8x\n", op1);
         $write("   Operand 2: ");
         if(op2_signedp) begin
            $write("  signed");
            if(op2_sign)
               $write(" - ");
            else
               $write(" + ");
         end
         $write("%8x\n", op2);
      endfunction

      // for printing.
      function string convert2string;
         return $sformatf("opcode=%x %s op1=%x %s op2=%x", opcode, (op1_signedp?"(s)":"   "), op1, (op2_signedp?"(s)":"   "), op2);
      endfunction

      // for copy
      function void do_copy(uvm_object rhs);
         input_transaction tx;

         // Because parent may have fields to copy, too.
         super.do_copy(rhs);

         $cast(tx, rhs);
         op1_signedp = tx.op1_signedp;
         op2_signedp = tx.op2_signedp;
         op1_sign    = tx.op1_sign;
         op2_sign    = tx.op2_sign;
         opcode      = tx.opcode;
         mux_select  = tx.mux_select;
         op1         = tx.op1;
         op2         = tx.op2;
      endfunction

      // for comparisons
      function bit do_compare(uvm_object rhs, uvm_comparer comparer);
         input_transaction tx;
         bit status = 1;

         // Because parent may have fields to compare, too.
         status &= super.do_compare(rhs, comparer);

         $cast(tx, rhs);
         status &= (op1_signedp == tx.op1_signedp);
         status &= (op2_signedp == tx.op2_signedp);
         status &= (op1_sign    == tx.op1_sign);
         status &= (op2_sign    == tx.op2_sign);
         status &= (opcode      == tx.opcode);
         status &= (mux_select  == tx.mux_select);
         status &= (op1         == tx.op1);
         status &= (op2         == tx.op2);

         return status;
      endfunction

   endclass : input_transaction

   // ----------------------------------------
   // I don't need to extend the sequencer.  Typedef will do.

   typedef uvm_sequencer #(input_transaction) input_sequencer;

   // ----------------------------------------
   // A basic test sequence.  As the name implies there may be more.

   class input_sequence_base extends uvm_sequence #(input_transaction);

      // register with factory
      `uvm_object_utils(input_sequence_base)

      // constructor
      function new (string name ="");
         super.new(name);
      endfunction

      // task body is required for this class, defined in parent.
      task body;

         // Prevent sim from exiting normally.  
         // starting_phase defined in parent.
         if (starting_phase != null)
            starting_phase.raise_objection(this);

         // just chuck in some random objects for now.
         repeat(10) begin
            // make yourself a transaction.
            // req defined in parent object
            req = input_transaction::type_id::create("req");
            // blocking call to synchronize with the driver.
            start_item(req);
            // proceeding - we're in sync
            // could do more here than just randomize().
            if (!req.randomize())
               `uvm_error(get_full_name(), "Transaction randomize failed.")
            // release the driver - your transaction is ready.
            finish_item(req);
         end 

         if (starting_phase != null)
            starting_phase.drop_objection(this);

      endtask: body

   endclass : input_sequence_base

   // ----------------------------------------
   // A long test sequence.  Maybe intended for bulk regressions?

   class input_sequence_long extends input_sequence_base;

      // register with factory
      `uvm_object_utils(input_sequence_long)

      // constructor
      function new (string name ="");
         super.new(name);
      endfunction

      // task body is required for this class, defined in parent.
      task body;
         my_config cfg;
         int num_tx;

         // Did we get a number of transactions in the config database?
         if (uvm_config_db #(my_config)::get(null, "", "config", cfg)) begin
            num_tx = cfg.num_tx;
         end
         else begin
            num_tx = 1000;  // sensible default
         end;

         `uvm_info(get_full_name(), $sformatf("num_tx = %0d", num_tx), UVM_LOW)

         // Prevent sim from exiting normally.  
         // starting_phase defined in parent.
         if (starting_phase != null)
            starting_phase.raise_objection(this);

         // And here we use that parameter from the config database to drive 
         // in random transactions.
         repeat(num_tx) begin
            // make yourself a transaction.
            // req defined in parent object
            req = input_transaction::type_id::create("req");
            // blocking call to synchronize with the driver.
            start_item(req);
            // proceeding - we're in sync
            // could do more here than just randomize().
            if (!req.randomize())
               `uvm_error(get_full_name(), "Transaction randomize failed.")
            // release the driver - your transaction is ready.
            finish_item(req);
         end 

         if (starting_phase != null)
            starting_phase.drop_objection(this);

      endtask: body

   endclass : input_sequence_long

   // ----------------------------------------
   // class for driver on the interface.

   class input_driver extends uvm_driver #(input_transaction);

      // register with factory
      `uvm_component_utils(input_driver)

      // instantiate the interface
      // I don't think this must be virtual.
      virtual dut_if dif;

      function new (string name, uvm_component parent);
         super.new(name, parent);
      endfunction

      function void build_phase (uvm_phase phase);
         // get inferface from config database, throw an error if this fails.
         if ( !uvm_config_db #(virtual dut_if)::get(this, "", "dut_if", dif))
            `uvm_error(get_full_name(), "uvm_config_db::get() call failed.")
      endfunction

      task run_phase(uvm_phase phase);

         // Initialize interface to known values.
         // req_valid is the key.  If this is zero the other signals are ignored.
         dif.req_valid       <= '0;

         // No reason to start looking for transactions until reset drops.
         @(negedge dif.reset);

         forever begin
            // Get yourself a transaction from the sequencer.
            seq_item_port.get_next_item(req);

            // Wait for posedge clock AND the unit is ready for a transaction.
            // This may be more than one clock.
            wait (dif.req_ready);
            @(posedge dif.clk);
            dif.req_valid       <= '1;
            dif.req_in_1_signed <= req.op1_signedp;
            dif.req_in_2_signed <= req.op2_signedp;
            dif.req_op          <= req.opcode;
            dif.req_out_sel     <= req.mux_select;
            dif.req_in_1        <= req.op1;
            dif.req_in_2        <= req.op2;
            @(posedge dif.clk);
            dif.req_valid       <= '0;

            seq_item_port.item_done();
         end
      endtask : run_phase

   endclass : input_driver

   // ----------------------------------------
   // Monitor for input transactions.

   class input_monitor extends uvm_monitor;

      // register with factory
      `uvm_component_utils(input_monitor)

      // virtual interface
      virtual dut_if dif;

      // Need an analysis port to broadcast what we find.
      uvm_analysis_port #(input_transaction) tx_collection_port;

      // Containers for observed transactions.
      input_transaction tx_collected;
      input_transaction tx_clone;

      // constructor
      function new (string name, uvm_component parent);
         super.new(name, parent);
      endfunction : new

      // build operations
      function void build_phase(uvm_phase phase);
         // parent builder
         super.build_phase(phase);

         // Get an interface from the config db.
         if ( !uvm_config_db #(virtual dut_if)::get(this, "", "dut_if", dif))
            `uvm_error(get_full_name(), "uvm_config_db::get() call failed.")

         // Build a new analysis port.
         tx_collection_port = new("tx_collection_port", this);

         // Allocate transactions.
         tx_collected = input_transaction::type_id::create("tx_collected");
         tx_clone     = input_transaction::type_id::create("tx_clone"    );
      endfunction : build_phase

      // This spawns off collect_transactions() task.
      virtual task run_phase(uvm_phase phase);
         fork
            collect_transactions();
         join
      endtask : run_phase

      // Guess what this does?
      virtual task collect_transactions();
         forever begin

            // FIXME - will need a tag if unit goes out-of-order.
            // Sync with rising clock edge.
            @(posedge dif.clk);
            // Only write if the we have a valid input.
            if (dif.req_valid) begin
               tx_collected.op1_signedp = dif.req_in_1_signed;
               tx_collected.op2_signedp = dif.req_in_2_signed;
               tx_collected.opcode      = dif.req_op;
               tx_collected.mux_select  = dif.req_out_sel;
               tx_collected.op1         = dif.req_in_1;
               tx_collected.op2         = dif.req_in_2;
               // have to compute sign from observed signals
               tx_collected.op1_sign    = (dif.req_in_1_signed)?(dif.req_in_1[`XPR_LEN-1]):'0;
               tx_collected.op2_sign    = (dif.req_in_2_signed)?(dif.req_in_2[`XPR_LEN-1]):'0;

               // deep copy, not a handle assignment.
               tx_clone.do_copy(tx_collected);

               // put that transaction on the port.
               tx_collection_port.write(tx_clone);
            end
         end
      endtask : collect_transactions

   endclass : input_monitor

   // ----------------------------------------
   // An agent class to wrap up sequencer, driver, and monitor.

   class input_agent extends uvm_agent;
      protected uvm_active_passive_enum is_active = UVM_ACTIVE;

      input_sequencer sequencer;
      input_driver    driver;
      input_monitor   monitor;

      `uvm_component_utils_begin(input_agent)
         `uvm_field_enum(uvm_active_passive_enum, is_active, UVM_ALL_ON)
      `uvm_component_utils_end

      // constructor
      function new (string name, uvm_component parent);
         super.new(name, parent);
      endfunction

      // build phase
      function void build_phase(uvm_phase phase);
         super.build_phase(phase);

         // we only build these for active agents
         if (is_active == UVM_ACTIVE) begin
            sequencer = input_sequencer::type_id::create("sequencer", this);
            driver    = input_driver   ::type_id::create("driver",    this);
         end

         // everyone gets a monitor
         monitor = input_monitor::type_id::create("monitor", this);

         // shout out
         `uvm_info(get_full_name(), "build stage complete.", UVM_LOW)
      endfunction : build_phase

      // connect phase
      function void connect_phase(uvm_phase phase);
         if(is_active == UVM_ACTIVE) 
            driver.seq_item_port.connect(sequencer.seq_item_export);

         `uvm_info(get_full_name(), "connect stage complete.", UVM_LOW)
      endfunction : connect_phase

   endclass : input_agent

   // ----------------------------------------
   // Define a transaction for outputs from the unit.

   class output_transaction extends uvm_sequence_item;

      // Register with object factory.
      `uvm_object_utils(output_transaction)

      // Output fields we need to capture.
      // FIXME - we'll need an ID field for out of order extension.
      logic [`XPR_LEN-1:0] result;

      // Class constructor.
      function new (string name ="");
         super.new(name);
      endfunction

      // For printing.
      function string convert2string;
         return $sformatf("result = %x", result);
      endfunction

      // For copy.
      function void do_copy(uvm_object rhs);
         output_transaction tx;

         // Because parent may have fields to copy, too.
         super.do_copy(rhs);

         $cast(tx, rhs);
         result = tx.result;
      endfunction

      // For comparisons.
      function bit do_compare(uvm_object rhs, uvm_comparer comparer);
         output_transaction tx;
         bit status = 1;

         // Because parent may have fields to compare, too.
         status &= super.do_compare(rhs, comparer);

         $cast(tx, rhs);
         status &= (result == tx.result);

         return status;
      endfunction

   endclass : output_transaction

   // ----------------------------------------
   // Monitor for output transactions.

   class output_monitor extends uvm_monitor;

      // Register with factory.
      `uvm_component_utils(output_monitor)

      // Virtual interface.
      virtual dut_if dif;

      // Need an analysis port to broadcast what we find.
      uvm_analysis_port #(output_transaction) tx_collection_port;

      // Containers for observed transactions.
      output_transaction tx_collected;
      output_transaction tx_clone;

      // constructor
      function new (string name, uvm_component parent);
         super.new(name, parent);
      endfunction : new

      // build operations
      function void build_phase(uvm_phase phase);
         // parent builder
         super.build_phase(phase);

         // Get an interface from the config db.
         if ( !uvm_config_db #(virtual dut_if)::get(this, "", "dut_if", dif))
            `uvm_error(get_full_name(), "uvm_config_db::get() call failed.")

         // Build a new analysis port.
         tx_collection_port = new("tx_collection_port", this);

         // Allocate transactions.
         tx_collected = output_transaction::type_id::create("tx_collected");
         tx_clone     = output_transaction::type_id::create("tx_clone"    );
      endfunction : build_phase

      // This spawns off collect_transactions() task.
      virtual task run_phase(uvm_phase phase);
         fork
            collect_transactions();
         join
      endtask : run_phase

      // Guess what this does?
      virtual task collect_transactions();
         forever begin

            // Here we sync with the valid bit as this is a multi-cycle
            // unit.  If this were out-of-order we'd need to get ID too.
            @(posedge dif.resp_valid);
            tx_collected.result = dif.resp_result;

            // Deep copy, not a handle assignment.
            tx_clone.do_copy(tx_collected);

            // Put that transaction on the port.
            tx_collection_port.write(tx_clone);
         end
      endtask : collect_transactions

   endclass : output_monitor

   // ----------------------------------------
   // This agent class watches the output of the unit.

   class output_agent extends uvm_agent;
      protected uvm_active_passive_enum is_active = UVM_PASSIVE;

      output_monitor   monitor;

      `uvm_component_utils_begin(output_agent)
         `uvm_field_enum(uvm_active_passive_enum, is_active, UVM_ALL_ON)
      `uvm_component_utils_end

      // constructor
      function new (string name, uvm_component parent);
         super.new(name, parent);
      endfunction

      // build phase
      function void build_phase(uvm_phase phase);
         super.build_phase(phase);

         // Everyone gets a monitor.
         monitor = output_monitor::type_id::create("monitor", this);

         // Shout out!
         `uvm_info(get_full_name(), "Build stage complete.", UVM_LOW)
      endfunction : build_phase

   endclass : output_agent

   // ----------------------------------------
   // A scoreboard to check results.

   class muldiv_scoreboard extends uvm_scoreboard;
      // An object to receive data from the agent's analysis port.
      uvm_tlm_analysis_fifo #(input_transaction)  tx_in_collected;
      uvm_tlm_analysis_fifo #(output_transaction) tx_out_collected;
      // Something to hold transactions.
      input_transaction input_tx;
      output_transaction output_tx;

      // Always, register with the factory.
      `uvm_component_utils(muldiv_scoreboard)

      // Stock constructor.
      function new(string name, uvm_component parent);
         super.new(name, parent);
      endfunction

      // Build-phase function to create objects.
      function void build_phase(uvm_phase phase);
         super.build_phase(phase);
         tx_in_collected = new("tx_in_collected", this);
         tx_out_collected = new("tx_out_collected", this);
         input_tx = input_transaction::type_id::create("input_tx");
         output_tx = output_transaction::type_id::create("output_tx");
         `uvm_info(get_full_name(), "Build phase complete.", UVM_LOW)
      endfunction : build_phase

      // Run-phase task only starts the data collection process.
      virtual task run_phase(uvm_phase phase);
         super.run_phase(phase);  // who knows what your parents are up to?
         watcher();
      endtask : run_phase

      // Get data from the analysis ports (plural) and run it through the checker.
      virtual task watcher();
         forever begin 
            tx_in_collected.get(input_tx);
            tx_out_collected.get(output_tx);
            compare_data();
         end
      endtask : watcher

      function [`XPR_LEN-1:0] get_absolute_value(logic [`XPR_LEN-1:0] operand, bit sign);
         // sign : 0 is positive, 1 is negative
         get_absolute_value = (sign) ? (~(operand - 1)) : operand;
      endfunction : get_absolute_value

      // Here, finally, we compare what we saw with what we expected.
      virtual task compare_data();
         logic [`DOUBLE_XPR_LEN-1:0] full_result;
         logic [`XPR_LEN-1:0] my_op1;
         logic [`XPR_LEN-1:0] my_op2;

         // Used for human-readable error reporting.
         string my_opcode;
         string my_round;

         // Get absolute values of inputs.
         my_op1 = get_absolute_value(input_tx.op1, input_tx.op1_sign);
         my_op2 = get_absolute_value(input_tx.op2, input_tx.op2_sign);

         // Predict value based on opcodes and operand signs.
         // Signed operations are not consistent.  REM is weird.
         case (input_tx.opcode)
            `MD_OP_MUL: begin
                  full_result = my_op1 * my_op2;
                  // Now factor in the signs.  If signed, and signs aren't the 
                  // same, find 2s complement of full result.
                  if ((input_tx.op1_signedp && input_tx.op2_signedp) && (input_tx.op1_sign != input_tx.op2_sign)) 
                     full_result = ~full_result + 1;
                  my_opcode = "MD_OP_MUL";
               end
            `MD_OP_DIV: begin
                  full_result = my_op1 / my_op2;
                  // Now factor in the signs.  If signed, and signs aren't the 
                  // same, find 2s complement of full result.
                  if ((input_tx.op1_signedp && input_tx.op2_signedp) && (input_tx.op1_sign != input_tx.op2_sign)) 
                     full_result = ~full_result + 1;
                  my_opcode = "MD_OP_DIV";
               end
            `MD_OP_REM: begin
                  full_result = my_op1 % my_op2;
                  // If dividend is negative, this implementation produces a 
                  // negative remainder.  Seems wrong but definion allows it.
                  if (input_tx.op1_signedp && input_tx.op1_sign) begin
                     full_result = (~full_result) + 1;
                  end 
                  my_opcode = "MD_OP_REM";
               end
            default: begin
               // If we're here we saw an undefined opcode.
               `uvm_error(get_full_name(), $sformatf("Unknown opcode %x seen.", input_tx.opcode))
               end
         endcase

         // Compare observed result based on mux setting.
         // Four-state compare to guard against unknowns.
         case (input_tx.mux_select)
            `MD_OUT_LO: begin
               my_round = "MD_OUT_LO";
               if (full_result[`XPR_LEN-1:0] !== output_tx.result) begin
                  `uvm_error(get_full_name(), $sformatf("Expected value %x does not match observed value %x.  Opcode %s, round mode %s.", full_result[`XPR_LEN-1:0], output_tx.result, my_opcode, my_round))
                  input_tx.print_full();
               end
            end
            `MD_OUT_HI: begin
               my_round = "MD_OUT_HI";
               if (full_result[`DOUBLE_XPR_LEN-1:`XPR_LEN] !== output_tx.result) begin
                  `uvm_error(get_full_name(), $sformatf("Expected value %x does not match observed value %x.  Opcode %s, round mode %s.", full_result[`DOUBLE_XPR_LEN-1:`XPR_LEN], output_tx.result, my_opcode, my_round))
                  input_tx.print_full();
               end
            end
            `MD_OUT_REM: begin
               my_round = "MD_OUT_REM";
               if (full_result[`XPR_LEN-1:0] !== output_tx.result) begin
                  `uvm_error(get_full_name(), $sformatf("Expected value %x does not match observed value %x.  Opcode %s, round mode %s.", full_result[`XPR_LEN-1:0], output_tx.result, my_opcode, my_round))
                  input_tx.print_full();
               end
            end
         endcase

      endtask : compare_data

   endclass : muldiv_scoreboard

   // ----------------------------------------
   // A coverage module for the test input.
   
   class input_coverage extends uvm_subscriber #(input_transaction);

      input_transaction tx;
      int tx_count;

      // Register with the factory.
      `uvm_component_utils(input_coverage);

      // Define cover group.
      // For now not covering data values.  Might be a gap.
      covergroup cov_operations;
         // 4 elements per group, only 3 are valid.
         ops: coverpoint tx.opcode;
         mux: coverpoint tx.mux_select;

         // Cross opcodes with mux selects.
         ops_mux: cross ops, mux;
      endgroup : cov_operations;

      // Constructor, which also has to allocate objects.
      function new(string name, uvm_component parent);
         super.new(name, parent);
         cov_operations = new();
      endfunction : new

      // This write() method receives data from the subscriber port.
      function void write(input_transaction in);
         // Sample the transaction data.
         tx = in;
         // Since we don't have a sample event we have to do this manually.
         cov_operations.sample();
         // This is local action to count number of transactions.
         tx_count++;
      endfunction : write

      // Extract phase runs after simulation.
      virtual function void extract_phase(uvm_phase phase);
         `uvm_info(get_type_name(), $sformatf("Number of transactions = %0d", tx_count), UVM_LOW)
         `uvm_info(get_type_name(), $sformatf("Current coverage = %2.2f", cov_operations.get_coverage()), UVM_LOW)
      endfunction : extract_phase

   endclass : input_coverage

   // ----------------------------------------
   // Environment class for the whole mess.
   // Right now this is overkill since we only have the one agent.

   class muldiv_env extends uvm_env;

      // Register with factory
      `uvm_component_utils(muldiv_env)

      // More agents than the CIA.
      input_agent  in_agent;
      output_agent out_agent;

      // A scoreboard to check the results.
      muldiv_scoreboard m_sbd;
      // A little coverage on unit input.
      input_coverage m_cov;

      // constructor
      function new(string name, uvm_component parent);
         super.new(name, parent);
      endfunction : new

      // build phase actions
      function void build_phase(uvm_phase phase);
         in_agent  = input_agent      ::type_id::create("in_agent" , this);
         out_agent = output_agent     ::type_id::create("out_agent", this);
         m_sbd     = muldiv_scoreboard::type_id::create("m_sbd",     this);
         m_cov     = input_coverage   ::type_id::create("m_cov",     this);
      endfunction : build_phase

      // Connect phase actions - need to connect scoreboard to agent monitors.
      function void connect_phase(uvm_phase phase);
         in_agent.monitor.tx_collection_port.connect(m_sbd.tx_in_collected.analysis_export);
         out_agent.monitor.tx_collection_port.connect(m_sbd.tx_out_collected.analysis_export);
         // m_cov is a child of uvm_subscriber and has an analysis port already
         in_agent.monitor.tx_collection_port.connect( m_cov.analysis_export );
      endfunction : connect_phase

   endclass : muldiv_env

   // ----------------------------------------
   // A class for your test.  This is kind of special, the one thing so far 
   // that we HAD to have.
   // FIXME : can I make a generic test class and then extend specific tests
   //         with their own run_phase options?  Something to explore later.

   class muldiv_test_1 extends uvm_test;

      // Always, register with class factory.
      `uvm_component_utils(muldiv_test_1)

      // instantiate the environment
      muldiv_env m_env;

      // constructor class
      function new(string name, uvm_component parent);
         super.new(name, parent);
      endfunction

      // Build phase, build yourself that environment you declared above.
      function void build_phase(uvm_phase phase);
         m_env = muldiv_env::type_id::create("m_env", this);
      endfunction

      // Run phase task, the body of this task creates and runs an input sequence.
      task run_phase(uvm_phase phase);
         input_sequence_base seq;
         seq = input_sequence_base::type_id::create("seq");
         `uvm_info(get_full_name(), "Running muldiv_test_1 now.", UVM_LOW)
         if (!seq.randomize())
            `uvm_error(get_full_name(), "Randomize failed.")
         seq.starting_phase = phase;
         seq.start( m_env.in_agent.sequencer );
      endtask

   endclass : muldiv_test_1

   // ----------------------------------------
   // A second test.

   class muldiv_test_2 extends uvm_test;

      // always, register with class factory
      `uvm_component_utils(muldiv_test_2)

      // instantiate the environment
      muldiv_env m_env;

      // This test wants some config action.
      my_config cfg;

      // constructor class
      function new(string name, uvm_component parent);
         super.new(name, parent);
      endfunction

      // Build phase, build yourself that environment you declared above.
      function void build_phase(uvm_phase phase);
         m_env = muldiv_env::type_id::create("m_env", this);

         // Set number of expected transactions.  Use config DB to share this.
         cfg = new;
         cfg.num_tx = 250;
         uvm_config_db #(my_config)::set(null, "", "config", cfg);
      endfunction


      // Run phase task.
      task run_phase(uvm_phase phase);
         input_sequence_base seq;
         // Override base type with derived type.
         input_sequence_base::type_id::set_type_override(input_sequence_long::get_type());
         seq = input_sequence_base::type_id::create("seq");
         `uvm_info(get_full_name(), "Running muldiv_test_2 now.", UVM_LOW)
         if (!seq.randomize())
            `uvm_error(get_full_name(), "Randomize failed.")
         seq.starting_phase = phase;
         seq.start( m_env.in_agent.sequencer );
      endtask

   endclass : muldiv_test_2

   // ----------------------------------------
   // A second test.

   class muldiv_test_3 extends uvm_test;

      // Always, register with class factory.
      `uvm_component_utils(muldiv_test_3)

      // Instantiate the environment.
      muldiv_env m_env;

      // This test wants some config action.
      my_config cfg;

      // Container for command line argument to catch the pass-by-reference
      // write from the UVM command line parser.
      string s_num_tx;

      // Need a pointer to the UVM command line parser.
      uvm_cmdline_processor cmdline;

      // constructor class
      function new(string name, uvm_component parent);
         super.new(name, parent);
      endfunction

      // build phase
      function void build_phase(uvm_phase phase);
         // Build yourself that environment you declared above.
         m_env = muldiv_env::type_id::create("m_env", this);

         // Allocate the configuration object.
         cfg = new;

         // Get a handle on the command line parser.  This is a singleton so
         // the build process is weird.
         cmdline = uvm_cmdline_processor::get_inst();

         // Query the parser for the one argument we care about.
         void' (cmdline.get_arg_value("+num_tx=", s_num_tx));

         // Convert that string result to an integer.
         if(s_num_tx.len() > 0)  // and there was an argument...
            cfg.num_tx = s_num_tx.atoi();
         else                    // ...else provide a default.
            cfg.num_tx = 100;

         `uvm_info(get_full_name(), $sformatf("num_tx argument = %s using %0d.", s_num_tx, cfg.num_tx), UVM_LOW)

         // Set number of expected transactions via the config DB.
         uvm_config_db #(my_config)::set(null, "", "config", cfg);
      endfunction

      // Run phase task.
      task run_phase(uvm_phase phase);
         input_sequence_base seq;
         // Override base type with derived type.
         input_sequence_base::type_id::set_type_override(input_sequence_long::get_type());
         seq = input_sequence_base::type_id::create("seq");
         `uvm_info(get_full_name(), "Running muldiv_test_3 now.", UVM_LOW)
         if (!seq.randomize())
            `uvm_error(get_full_name(), "Randomize failed.")
         seq.starting_phase = phase;
         seq.start( m_env.in_agent.sequencer );
      endtask

   endclass : muldiv_test_3

endpackage : vscale_mul_div_unit

// ------------------------------------------------------------------------------
// An interface for the DUT.  DUT doesn't need it.  But it makes it so much more
// convenient to connect UVM objects to the interface.

interface dut_if;
   // Clock and reset from system.
   logic                         clk;
   logic                         reset;
   // Valid bit for "req" logics.
   logic                         req_valid;
   // Unit ready to receive a request.
   logic                         req_ready;
   // Are logics signed?  It's integer arithmetic, no explicit sign bit.
   logic                         req_in_1_signed;
   logic                         req_in_2_signed;
   // Opcode
   logic [`MD_OP_WIDTH-1:0]      req_op;
   // Trying to get 64 bits out on a 32-bit bus.  This controls the output mux.
   logic [`MD_OUT_SEL_WIDTH-1:0] req_out_sel;
   // Next two signals are the operands.
   logic [`XPR_LEN-1:0]          req_in_1;
   logic [`XPR_LEN-1:0]          req_in_2;
   // Valid bit on output, necessary on a variable-latency operation.
   logic                        resp_valid;
   // Arithmetic result.  
   logic [`XPR_LEN-1:0]         resp_result;
endinterface : dut_if

// ------------------------------------------------------------------------------
// Top-level module for unit test environment.

module top;

   // Import packages.
   import uvm_pkg::*;

   // Name the test via command-line interface.
   string test_name;

   // Get a handle on the UVM command line parser.
   uvm_cmdline_processor cmdline;

   // Declare an interface (with null ports) for the DUT.
   dut_if dif ();

   // Instantiate the DUT.
   // Module interface is ugly because module is old-school Verilog and
   // doesn't understand the SystemVerilog interface class I'm using.
   vscale_mul_div dut(
      dif.clk,
      dif.reset,
      dif.req_valid,
      dif.req_ready,
      dif.req_in_1_signed,
      dif.req_in_2_signed,
      dif.req_op,
      dif.req_out_sel,
      dif.req_in_1,
      dif.req_in_2,
      dif.resp_valid,
      dif.resp_result
   );

   // Make a clock.
   initial begin
      dif.clk = 1'b1;
      forever #5 dif.clk = ~dif.clk;
   end
   
   // Assert reset for DUT.
   // FIXME add assertion control here, too?
   initial begin
      dif.reset = 1'b1;
      #20 dif.reset = 1'b0;
   end

   // Test control block.
   initial begin
      // Enable dumping for waveform view.
      $dumpfile("dump.vcd");
      $dumpvars;
      // Register DUT interface with factory.
      uvm_config_db #(virtual dut_if)::set(null, "*", "dut_if", dif);
      // If set, then run_test will call $finish after all phases are executed.
      uvm_top.finish_on_completion = 1;

      // Get handle to the command line processor singleton object.
      cmdline = uvm_cmdline_processor::get_inst();
      // And read that command line value.  Result written to test_name arugment.
      void' (cmdline.get_arg_value("+test=", test_name));
      // Safety value in case user didn't provide an option.
      // FIXME - right now we just die if it's not a legal test case.
      if(test_name.len() == 0) test_name = "muldiv_test_3";

      // Whatever it was, run the test.
      run_test(test_name);
   end

   // End-of-test housekeeping.
   final begin
      // Print coverage results.
      `uvm_info("", $sformatf("Overall coverage = %02.2f", $get_coverage()), UVM_NONE)
   end

endmodule : top

