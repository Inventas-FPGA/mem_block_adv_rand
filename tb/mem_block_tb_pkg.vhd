library ieee;
use ieee.std_logic_1164.all;
library uvvm_util;
context uvvm_util.uvvm_util_context;

package mem_block_tb_pkg is
  constant C_CLK_PERIOD      : time    := 10 ns;
  constant C_SBI_VVC_IDX     : natural := 1;
  constant C_CLK_GEN_VVC_IDX : natural := 1;
  constant C_DATA_ZERO       : natural := 0;
  constant C_DATA_ONES       : natural := 1;
  constant C_DATA_MIXED      : natural := 2;

  function classify_data(data_word : std_logic_vector) return natural;

  procedure configure_coverage(
    variable address_cp, data_cp, cross_cp : inout t_coverpoint;
    constant last_address                  : in    positive;
    constant min_hits                      : in    positive := 1);

end package;

package body mem_block_tb_pkg is

  function classify_data(data_word : std_logic_vector) return natural is
  begin
    if data_word = (data_word'range => '0') then
      return C_DATA_ZERO;
    elsif data_word = (data_word'range => '1') then
      return C_DATA_ONES;
    else
      return C_DATA_MIXED;
    end if;
  end;

  procedure configure_coverage(
    variable address_cp, data_cp, cross_cp : inout t_coverpoint;
    constant last_address                  : in    positive;
    constant min_hits                      : in    positive := 1) is
  begin
    address_cp.set_name("Address");
    address_cp.add_bins(bin(0), min_hits, "first");
    address_cp.add_bins(bin_range(1, last_address-1, 1), min_hits, "mid");
    address_cp.add_bins(bin(last_address), min_hits, "last");

    data_cp.set_name("Data");
    data_cp.add_bins(bin(C_DATA_ZERO), min_hits, "zero");
    data_cp.add_bins(bin(C_DATA_ONES), min_hits, "ones");
    data_cp.add_bins(bin(C_DATA_MIXED), min_hits, "mixed");
    
    cross_cp.set_name("Address_X_Data");
    cross_cp.add_cross(address_cp, data_cp, min_hits);
  end;
end package body;
