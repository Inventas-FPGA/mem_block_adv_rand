
--HDLRegression:TB
entity tb_3_testcase is
    generic (
        GC_TESTCASE : string    := "UVVM_TB"
        );
end tb_3_testcase;


architecture testcase_arch of tb_3_testcase is
begin

    p_seq : process
    begin

        if GC_TESTCASE = "testcase_1" then
            report "passing testcase";
        elsif (GC_TESTCASE = "testcase_2") then
            report "passing testcase";
        elsif ( GC_TESTCASE = "testcase_3" ) then
            report "passing testcase";
        else
            report "unknown testcase : " & GC_TESTCASE;
        end if;
        
        -- Finish the simulation
        std.env.stop;
        wait;  -- to stop completely
    end process;

end architecture testcase_arch;