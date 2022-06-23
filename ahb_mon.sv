class ahb_mon extends uvm_monitor;
  uvm_analysis_port#(ahb_tx) ap_port;
  
  ahb_tx tx; //the transaction class declared to collect all transactions
  
  virtual ahb_intf.mon_mp vif; // no need for arbitration vif when monitoring 
  
  trans_t prev_htrans = IDLE; //from ahb_common.sv
  
  `uvm_component_utils(ahb_mon)
  `NEW_COMP
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap_port = new("ap_port", this);
    if(!uvm_resource_db#(virtual ahb_intf)::read_by_type("AHB", vif, this)) begin
      `uvm_error("RESOURCE_DB_ERROR", "Not able to retrieve ahb_vif handle from resource_db")
    end
  endfunction
  
  task run_phase(uvm_phase phase);
    forever begin
     @(vif.mon_cb);
     //if(vif.mon_cb.hreadyout == 1) begin
      
      case (vif.mon_cb.htrans) //current_htrans
        IDLE : begin
          case (prev_htrans)
            IDLE : begin
              //Do nothing since there won't be any address and data phase
            end
            BUSY : begin
              `uvm_error("AHB_TX", "Illegal Htrans scenario : H_TRANS_BUSY_IDLE")
            end
            NONSEQ, SEQ : begin
              collect_data_phase();
              ap_port.write(tx);
              $display("WRITING TX TO AP_PORT);
              tx.print();
            end
          endcase
        end
        BUSY : begin
          case (prev_htrans)
            IDLE : begin
              `uvm_error("AHB_TX", "Illegal Htrans scenario : H_TRANS_IDLE_BUSY")
            end
            BUSY : begin
              //Do nothing
            end
            NONSEQ, SEQ : begin
              collect_data_phase();
            end
          endcase
        end
        NONSEQ : begin
          case (prev_htrans)
            IDLE : begin
              collect_addr_phase();
            end
            BUSY : begin
              `uvm_error("AHB_TX", "Illegal Htrans scenario : H_TRANS_BUSY_NONSEQ")
            end
            NONSEQ, SEQ : begin
              collect_data_phase();
              ap_port.write(tx);
              $display("WRITING TX TO AP_PORT");
              tx.print();
              collect_addr_phase(); //a new tx is starting so earlier tx should be written to ap_port
            end
          endcase
        end
        SEQ : begin
          case (prev_htrans)
            IDLE : begin
              `uvm_error("AHB_TX", "Illegal Htrans scenario : H_TRANS_IDLE_SEQ")
            end
            BUSY : begin
              //collect_addr_phase(); //we should not collect since it will override existing addr information
            end
            NONSEQ, SEQ : begin
              collect_data_phase();
              //collect_addr_phase();
            end
          endcase
        end
      endcase
      prev_htrans = trans_t'(vif.mon_cb.htrans); //current htrans becomes previous htrans for next cycle
      //static casting from bit to enum
     //end
    end
  endtask
  
  task collect_addr_phase();
    tx = ahb_tx::type_id::create("tx");
    tx.addr = vif.mon_cb.haddr;
    tx.burst = burst_t'(vif.mon_cb.hburst); //static casting from bit to enum
    tx.prot = vif.mon_cb.hprot;
    tx.size = vif.mon_cb.hsize;
    tx.nonsec = vif.mon_cb.hnonsec;
    tx.excl = vif.mon_cb.hexcl;
    tx.wr_rd = vif.mon_cb.hwrite;
  endtask
  
  task collect_data_phase();
    if (tx.wr_rd == 1) begin
      /*$display("%t: collect_data_phase_collected, addr = %h, data = %h, wr_rd = %h", $time, tx.addr, vif.mon_cb.hwdata, tx.wr_rd); //debugging why data wasn't outputted*/
      `uvm_info("MON", $psprintf("%t: collect_data_phase_collected, addr = %h, data = %h, wr_rd = %h", $time, tx.addr, vif.mon_cb.hwdata, tx.wr_rd), UVM_FULL)
      tx.dataQ.push_back(vif.mon_cb.hwdata);
    end
    if (tx.wr_rd == 0) begin
      $display("%t: collect_data_phase_collected, addr = %h, data = %h, wr_rd = %h", $time, tx.addr, vif.mon_cb.hrdata, tx.wr_rd);
      tx.dataQ.push_back(vif.mon_cb.hrdata);
    end
  endtask
  
endclass

/*ahb_mon monitors the interface and collects the transactions/items. It collects all data phases and first address phase only.

I copied the responder code's HTRANS possiblities code along with the address and data phase tasks. Except this time I am creating a transaction called tx in the address phase, and storing all the addr phase and data phase signals into that transaction. The addr phase doesn't have a concept of htrans bring collected. 

I did static casting of vif.htrans and vif.hburst to trans_t and burst_t respectively, to go from bit to enum.

We only want monitor to collect address once for each INCR4 during NONSEQ, because we don't want to override existing addr information, so we comment out the collect_addr_phase()s for SEQ.

No data was being outputted during print. I added display statements in the data phases and they did show data, not necessarily the right ones though. I commented out the monitor in the slave agent to just focus on my master agent. I also commented out the req.print() in the driver to avoid duplicate printing.

Issues:

1) Address was the same maybe because we didn't increment addr_t, and the data was collected two times. Data is printed from monitor, same data collected two times, the dataQ has 5 items instead of 4 items.
2) There is a problem with read transaction, debugged it by writing to analysis port when we have HTRANS_NONSEQ/SEQ_IDLE. Also, we write to analysis port for HTRANS_NONSEQ/SEQ_NONSEQ. Both cases are when we have new transactions.
3) Another read transaction problem is data is not being printed, but now is being collected at least. Thinking we might need modport and clocking block.