library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library uvvm_vvc_framework;
context uvvm_vvc_framework.vvc_framework_context;

library bitvis_vip_sbi;
context bitvis_vip_sbi.vvc_context;

library bitvis_vip_clock_generator;
context bitvis_vip_clock_generator.vvc_context;

library test_lib;
use test_lib.mem_block_tb_pkg.all;

--hdlregression:tb
entity mem_block_tb is
  generic (
    GC_TESTCASE       : string := "optimized_rand";
    GC_ADDR_WIDTH     : positive := 12;
    GC_DATA_WIDTH     : positive := 32;
    GC_SEED           : positive := 17;
    GC_ITERATIONS     : positive := 64;   -- Basic/enhanced fixed budget
    GC_MAX_ITERATIONS : positive := 1000; -- Optimized safety limit
    GC_MIN_HITS       : positive := 1     -- Required hits per bin
  );
end entity;

architecture tb of mem_block_tb is

  constant C_LAST_ADDRESS : natural := 2**GC_ADDR_WIDTH-1;
  signal clock : std_logic;
  signal reset : std_logic := '0';
  signal watchdog_control : t_watchdog_ctrl := C_WATCHDOG_CTRL_DEFAULT;

begin

  i_th : entity work.mem_block_th
    generic map(GC_ADDR_WIDTH => GC_ADDR_WIDTH,
                GC_DATA_WIDTH => GC_DATA_WIDTH)
    port map(clk   => clock,
             reset => reset);

  watchdog_timer(watchdog_control, 10 ms, TB_ERROR, "Memory demo timed out");

  p_test_sequencer : process

    variable v_addr_random, v_data_random        : t_rand;
    variable v_addr_cp, v_data_cp, v_cross_cp    : t_coverpoint;
    variable v_addr                              : integer;
    variable v_data                              : std_logic_vector(GC_DATA_WIDTH-1 downto 0);
    variable v_combination                       : integer_vector(0 to 1); -- Address, data class
    variable v_seed_1                            : positive := GC_SEED;
    variable v_seed_2                            : positive := GC_SEED+101;
    variable v_completed_checks                  : natural := 0;

    procedure write_and_check(address : natural; data_word : std_logic_vector) is
    begin
      sbi_write(SBI_VVCT, C_SBI_VVC_IDX, to_unsigned(address, GC_ADDR_WIDTH), data_word, "Write data");
      sbi_check(SBI_VVCT, C_SBI_VVC_IDX, to_unsigned(address, GC_ADDR_WIDTH), data_word, "Check written data");
      await_completion(SBI_VVCT, C_SBI_VVC_IDX, 1 ms, "Wait for write and check");
    end;

    impure function get_write_data(data_class : natural) return std_logic_vector is
      variable v_data_word : std_logic_vector(GC_DATA_WIDTH-1 downto 0);
    begin
      case data_class is
        when C_DATA_ZERO => 
          -- all zero
          v_data_word := (others => '0');
        when C_DATA_ONES => 
          -- all one
          v_data_word := (others => '1');
        when others =>
          -- random
          v_data_word := v_data_random.rand(GC_DATA_WIDTH);
      end case;
      return v_data_word;
    end;

    procedure sample_coverage(address : natural; data_word : std_logic_vector) is
    begin
      v_addr_cp.sample_coverage(address);
      v_data_cp.sample_coverage(classify_data(data_word));
      v_cross_cp.sample_coverage(integer_vector'(address, classify_data(data_word)));
      v_completed_checks := v_completed_checks+1;
    end;
  
  begin

    --
    -- Prepare testbench environment
    --
    await_uvvm_initialization(VOID);

    shared_sbi_vvc_config(C_SBI_VVC_IDX).bfm_config.clock_period := C_CLK_PERIOD;
    start_clock(CLOCK_GENERATOR_VVCT, C_CLK_GEN_VVC_IDX, "Start clock");

    -- set seeds
    v_addr_random.set_rand_seeds(GC_SEED, GC_SEED+101);
    v_data_random.set_rand_seeds(GC_SEED+1, GC_SEED+102);

    configure_coverage(v_addr_cp, v_data_cp, v_cross_cp, C_LAST_ADDRESS, GC_MIN_HITS);
    v_cross_cp.set_rand_seeds(GC_SEED+2, GC_SEED+103);
    
    gen_pulse(reset, '1', 2*C_CLK_PERIOD, BLOCKING, "Pulsing reset");
    wait for C_CLK_PERIOD;
    
    log(ID_LOG_HDR, "TC=" & GC_TESTCASE & " , seed=" & to_string(GC_SEED));

    ------------------------------------------------------
    -- Basic randomization
    ------------------------------------------------------
    if GC_TESTCASE = "basic_rand" then
      for idx in 1 to GC_ITERATIONS loop
        random(0, C_LAST_ADDRESS, v_seed_1, v_seed_2, v_addr);
        random(v_seed_1, v_seed_2, v_data);

        write_and_check(v_addr, v_data);
        sample_coverage(v_addr, v_data);
      end loop;

      
    ------------------------------------------------------
    -- Enhanced randomization
    ------------------------------------------------------
    elsif GC_TESTCASE = "enhanced_single_method" then
      for idx in 1 to GC_ITERATIONS loop
        v_addr := v_addr_random.rand_range_weight(((0,0,1), (1,C_LAST_ADDRESS-1,1), (C_LAST_ADDRESS,C_LAST_ADDRESS,1)));
        v_data := get_write_data(v_data_random.rand(C_DATA_ZERO, C_DATA_MIXED));

        write_and_check(v_addr, v_data);
        sample_coverage(v_addr, v_data);
      end loop;


    elsif GC_TESTCASE = "enhanced_multi_method" then
      v_addr_random.add_val_weight(0, 1);
      v_addr_random.add_range_weight(1, C_LAST_ADDRESS-1, 1, COMBINED_WEIGHT);
      v_addr_random.add_val_weight(C_LAST_ADDRESS, 1);

      for idx in 1 to GC_ITERATIONS loop
        v_addr := v_addr_random.randm(VOID);
        v_data := get_write_data(v_data_random.rand(C_DATA_ZERO, C_DATA_MIXED));
      
        write_and_check(v_addr, v_data);
        sample_coverage(v_addr, v_data);
      end loop;


    ------------------------------------------------------
    -- Functional coverage
    ------------------------------------------------------
    elsif GC_TESTCASE = "coverage_holes" then
      for idx in 1 to GC_MIN_HITS loop
        for data_class in C_DATA_ZERO to C_DATA_MIXED loop
          
          case data_class is
            when C_DATA_ZERO =>
              v_addr := 0;
            when C_DATA_ONES =>
              v_addr := 1;
            when others => 
              v_addr := C_LAST_ADDRESS;
          end case;

          v_data := get_write_data(data_class);
          
          write_and_check(v_addr, v_data);
          sample_coverage(v_addr, v_data);
        end loop;
      end loop;

      check_value(v_addr_cp.coverage_completed(BINS_AND_HITS),  true,  ERROR, "CP: address complete");
      check_value(v_data_cp.coverage_completed(BINS_AND_HITS),  true,  ERROR, "CP: data complete");
      check_value(v_cross_cp.coverage_completed(BINS_AND_HITS), false, ERROR, "CP: cross holes expected");


    ------------------------------------------------------
    -- Optimized randomization
    ------------------------------------------------------
    elsif GC_TESTCASE = "optimized_rand" then
      while not v_cross_cp.coverage_completed(BINS_AND_HITS) and v_completed_checks < GC_MAX_ITERATIONS loop
        v_combination := v_cross_cp.rand(NO_SAMPLE_COV);
        v_addr        := v_combination(0);
        v_data        := get_write_data(v_combination(1));

        write_and_check(v_addr, v_data);
        sample_coverage(v_addr, v_data);
      end loop;
      
      check_value(v_cross_cp.coverage_completed(BINS_AND_HITS), true, ERROR, "Cross coverage missed");
    

    else
      alert(TB_FAILURE, "Unknown testcase: " & GC_TESTCASE);
    end if;

    log(ID_LOG_HDR, "Completed checks: " & to_string(v_completed_checks));
    v_addr_cp.report_coverage(VOID);
    v_data_cp.report_coverage(VOID);
    v_cross_cp.report_coverage(VOID);
    
    report_alert_counters(FINAL);
    log(ID_LOG_HDR, "SIMULATION COMPLETED");
    std.env.stop;
    wait;
  end process;
end architecture;
