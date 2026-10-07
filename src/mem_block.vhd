library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mem_block is
  generic (
    GC_ADDR_WIDTH : positive := 12;
    GC_DATA_WIDTH : positive := 32
  );
  port (
    clk   : in  std_logic;
    rst   : in  std_logic;
    cs    : in  std_logic;
    wena  : in  std_logic;
    rena  : in  std_logic;
    addr  : in  unsigned(GC_ADDR_WIDTH-1 downto 0);
    wdata : in  std_logic_vector(GC_DATA_WIDTH-1 downto 0);
    rdata : out std_logic_vector(GC_DATA_WIDTH-1 downto 0);
    ready : out std_logic
  );
end entity;

architecture rtl of mem_block is

  constant C_DEPTH : positive := 2**GC_ADDR_WIDTH;
  type t_mem is array (0 to C_DEPTH-1) of std_logic_vector(GC_DATA_WIDTH-1 downto 0);
  signal mem : t_mem := (others => (others => '0'));

  function decode(a : unsigned) return natural is
    variable n : natural := to_integer(a);
  begin
    if n = C_DEPTH-1 then
      return C_DEPTH-2; 
    else
      return n;
    end if;
  end;

begin

    -- Retains the original asynchronous reset and clocked write contract.
  p_write : process(clk, rst)
  begin
    if rst = '1' then
      mem <= (others => (others => '0'));
    elsif rising_edge(clk) then
      if cs = '1' and wena = '1' then mem(decode(addr)) <= wdata; end if;
    end if;
  end process;

  -- Asynchronous read; deterministic zero when inactive (no output latch).
  -- If read and write are both asserted, read reflects new data after delta cycles.
  p_read : process(all)
  begin
    rdata <= (others => '0');
    if rst = '0' and cs = '1' and rena = '1' then
      rdata <= mem(decode(addr));
    end if;
  end process;
  
  ready <= '1';

end architecture;
