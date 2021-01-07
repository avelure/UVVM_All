--================================================================================================================================
-- Copyright 2020 Bitvis
-- Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0 and in the provided LICENSE.TXT.
--
-- Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
-- an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and limitations under the License.
--================================================================================================================================
-- Note : Any functionality not explicitly described in the documentation is subject to change at any time
----------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------
-- Description   : See library quick reference (under 'doc') and README-file(s)
------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.types_pkg.all;
use work.adaptations_pkg.all;
use work.string_methods_pkg.all;
use work.global_signals_and_shared_variables_pkg.all;
use work.methods_pkg.all;
use work.rand_pkg.all;

package funct_cov_pkg is

  --TODO: move to adaptations_pkg?
  constant C_MAX_NUM_BINS        : positive := 100;
  constant C_MAX_NUM_BIN_VALUES  : positive := 10;
  constant C_MAX_BIN_NAME_LENGTH : positive := 20;

  ------------------------------------------------------------
  -- Types
  ------------------------------------------------------------
  type t_cov_bin_type is (VAL, VAL_IGNORE, VAL_ILLEGAL, RAN, RAN_IGNORE, RAN_ILLEGAL, TRN);
  type t_overlap_action is (ALERT, COUNT_ALL, COUNT_ONE);

  type t_new_bin is record
    contains   : t_cov_bin_type;
    values     : integer_vector(0 to C_MAX_NUM_BIN_VALUES-1);
    num_values : natural;
  end record;
  type t_new_bin_vector is array (natural range <>) of t_new_bin;

  type t_cov_bin is record
    contains       : t_cov_bin_type;
    values         : integer_vector(0 to C_MAX_NUM_BIN_VALUES-1);
    num_values     : natural;
    transition_idx : natural;
    hits           : natural;
    min_hits       : natural;
    weight         : natural;
    name           : string(1 to C_MAX_BIN_NAME_LENGTH);
  end record;
  type t_cov_bin_vector is array (natural range <>) of t_cov_bin;

  ------------------------------------------------------------
  -- Functions
  ------------------------------------------------------------
  -- Creates a bin with a single value
  function bin(
    constant value      : integer)
  return t_new_bin_vector;

  -- Creates a bin with multiple values
  function bin(
    constant set_values : integer_vector)
  return t_new_bin_vector;

  -- Divides a range of values into a number bins. If num_bins is 0 then a bin is created for each value.
  -- e.g. (0,10) -> 11 bins [0,1,2,...,10] // (0,10,1) -> 1 bin [0:10] // (0,10,2) -> 2 bins [0:5] [6:10]
  function bin_range(
    constant min_value  : integer;
    constant max_value  : integer;
    constant num_bins   : natural := 0)
  return t_new_bin_vector;

  -- Creates a bin for each value in the vector's range
  function bin_vector(
    constant vector     : std_logic_vector)
  return t_new_bin_vector;

  -- Creates a bin a transition of values
  function bin_transition(
    constant set_values : integer_vector)
  return t_new_bin_vector;

  -- Creates an ignore bin with a single value
  function ignore_bin(
    constant value      : integer)
  return t_new_bin_vector;

  -- Creates an ignore bin with a range of values
  function ignore_bin_range(
    constant min_value  : integer;
    constant max_value  : integer)
  return t_new_bin_vector;

  -- Creates an illegal bin with a single value
  function illegal_bin(
    constant value      : integer)
  return t_new_bin_vector;

  -- Creates an illegal bin with a range of values
  function illegal_bin_range(
    constant min_value  : integer;
    constant max_value  : integer)
  return t_new_bin_vector;

  ------------------------------------------------------------
  -- Protected type
  ------------------------------------------------------------
  type t_cov_point is protected

    ------------------------------------------------------------
    -- Configuration
    ------------------------------------------------------------
    procedure set_scope(
      constant scope : in string);

    impure function get_scope(
      constant VOID : t_void)
    return string;

    ------------------------------------------------------------
    -- Bins
    ------------------------------------------------------------
    procedure add_bins(
      constant bin           : in t_new_bin_vector;
      constant min_cov       : in positive;
      constant rand_weight   : in natural;
      constant bin_name      : in string         := "";
      constant msg_id_panel  : in t_msg_id_panel := shared_msg_id_panel);

    procedure add_bins(
      constant bin           : in t_new_bin_vector;
      constant min_cov       : in positive;
      constant bin_name      : in string         := "";
      constant msg_id_panel  : in t_msg_id_panel := shared_msg_id_panel);

    procedure add_bins(
      constant bin           : in t_new_bin_vector;
      constant bin_name      : in string         := "";
      constant msg_id_panel  : in t_msg_id_panel := shared_msg_id_panel);

    ------------------------------------------------------------
    -- Randomization
    ------------------------------------------------------------
    impure function rand(
      constant msg_id_panel  : in t_msg_id_panel := shared_msg_id_panel)
    return integer;

    ------------------------------------------------------------
    -- Coverage
    ------------------------------------------------------------
    procedure sample_coverage(
      constant value         : in integer;
      constant msg_id_panel  : in t_msg_id_panel := shared_msg_id_panel);

    procedure print_summary(
      constant VOID : in t_void);

  end protected t_cov_point;

end package funct_cov_pkg;

package body funct_cov_pkg is

  ------------------------------------------------------------
  -- Functions
  ------------------------------------------------------------
  -- Creates a bin with a single value
  function bin(
    constant value      : integer)
  return t_new_bin_vector is
    variable v_ret : t_new_bin_vector(0 to 0);
  begin
    v_ret(0).contains   := VAL;
    v_ret(0).values(0)  := value;
    v_ret(0).num_values := 1;
    return v_ret;
  end function;

  -- Creates a bin with multiple values
  function bin(
    constant set_values : integer_vector)
  return t_new_bin_vector is
    variable v_ret : t_new_bin_vector(0 to 0);
  begin
    v_ret(0).contains   := VAL;
    v_ret(0).values(0 to set_values'length-1) := set_values;
    v_ret(0).num_values := set_values'length;
    return v_ret;
  end function;

  -- Divides a range of values into a number bins. If num_bins is 0 then a bin is created for each value.
  -- e.g. (0,10) -> 11 bins [0,1,2,...,10] // (0,10,1) -> 1 bin [0:10] // (0,10,2) -> 2 bins [0:5] [6:10]
  --Q: if division has a residue, either leave it to the last bin or spread it among bins (OSSVM)
  --   -- 1 to 2, 3 to 4, 5 to 6, 7 to 10
  --   -- 1 to 2, 3 to 4, 5 to 7, 8 to 10
  -- **10 /  1; = 10                -- 1 to 10
  -- **10 /  2; = 5                 -- 1 to 5, 6 to 10
  -- 10 /  4; = 2 (round down 2.5)  -- 1 to 2, 3 to 4, 5 to 6, 7 to 8
  -- 10 /  9; = 1 (round down 1.1)
  -- **10 / 10; = 1                 -- 1 to 1, 2 to 2, ...,  10 to 10
  -- **10 / 11; = 0                 -- 1 to 1, 2 to 2, ...,  10 to 10
  function bin_range(
    constant min_value  : integer;
    constant max_value  : integer;
    constant num_bins   : natural := 0)
  return t_new_bin_vector is
    constant C_RANGE_WIDTH : integer := (max_value - min_value + 1); --TODO: absolute value
    variable v_div_range   : integer;
    variable v_num_bins    : integer;
    variable v_ret : t_new_bin_vector(0 to C_RANGE_WIDTH-1);
  begin
    -- Create a bin for each value in the range
    if num_bins = 0 then
      for i in min_value to max_value loop
        v_ret(i-min_value to i-min_value) := bin(i);
      end loop;
      v_num_bins  := C_RANGE_WIDTH;
    -- Create several bins
    elsif min_value <= max_value then
      if C_RANGE_WIDTH > num_bins then
        v_div_range := C_RANGE_WIDTH / num_bins;
        v_num_bins  := num_bins;
      else
        v_div_range := C_RANGE_WIDTH;
        v_num_bins  := 1;
      end if;
      --TODO: figure out what to do with remaining values
      for i in 0 to v_num_bins-1 loop
        v_ret(i).contains   := RAN;
        v_ret(i).values(0)  := min_value+v_div_range*i;
        v_ret(i).values(1)  := min_value+v_div_range*(i+1)-1;
        v_ret(i).num_values := 2;
      end loop;
    else
      --alert(TB_ERROR, v_proc_call.all & "=> Failed. min_value must be less than max_value", priv_scope.all);
    end if;
    return v_ret(0 to v_num_bins-1);
  end function;

  -- Creates a bin for each value in the vector's range
  function bin_vector(
    constant vector     : std_logic_vector)
  return t_new_bin_vector is
    variable v_ret : t_new_bin_vector(0 to 2**vector'length-1);
  begin
    for i in v_ret'range loop
      v_ret(i to i) := bin(i);
    end loop;
    return v_ret;
  end function;

  -- Creates a bin a transition of values
  function bin_transition(
    constant set_values : integer_vector)
  return t_new_bin_vector is
    variable v_ret : t_new_bin_vector(0 to 0);
  begin
    v_ret(0).contains   := TRN;
    v_ret(0).values(0 to set_values'length-1) := set_values;
    v_ret(0).num_values := set_values'length;
    return v_ret;
  end function;

  -- Creates an ignore bin with a single value
  function ignore_bin(
    constant value      : integer)
  return t_new_bin_vector is
    variable v_ret : t_new_bin_vector(0 to 0);
  begin
    v_ret(0).contains   := VAL_IGNORE;
    v_ret(0).values(0)  := value;
    v_ret(0).num_values := 1;
    return v_ret;
  end function;

  -- Creates an ignore bin with a range of values
  function ignore_bin_range(
    constant min_value  : integer;
    constant max_value  : integer)
  return t_new_bin_vector is
    variable v_ret : t_new_bin_vector(0 to 0);
  begin
    v_ret(0).contains   := RAN_IGNORE;
    v_ret(0).values(0)  := min_value;
    v_ret(0).values(1)  := max_value;
    v_ret(0).num_values := 2;
    return v_ret;
  end function;

  -- Creates an illegal bin with a single value
  function illegal_bin(
    constant value      : integer)
  return t_new_bin_vector is
    variable v_ret : t_new_bin_vector(0 to 0);
  begin
    v_ret(0).contains   := VAL_ILLEGAL;
    v_ret(0).values(0)  := value;
    v_ret(0).num_values := 1;
    return v_ret;
  end function;

  -- Creates an illegal bin with a range of values
  function illegal_bin_range(
    constant min_value  : integer;
    constant max_value  : integer)
  return t_new_bin_vector is
    variable v_ret : t_new_bin_vector(0 to 0);
  begin
    v_ret(0).contains   := RAN_ILLEGAL;
    v_ret(0).values(0)  := min_value;
    v_ret(0).values(1)  := max_value;
    v_ret(0).num_values := 2;
    return v_ret;
  end function;

  ------------------------------------------------------------
  -- Protected type
  ------------------------------------------------------------
  type t_cov_point is protected body
    variable priv_scope                         : line    := new string'(C_SCOPE);
    variable priv_bins                          : t_cov_bin_vector(0 to C_MAX_NUM_BINS-1);
    variable priv_bin_idx                       : natural := 0;
    variable priv_rand_gen                      : t_rand;
    variable priv_rand_transition_bin_idx       : integer := -1;
    variable priv_rand_transition_bin_value_idx : natural := 0;

    ------------------------------------------------------------
    -- Internal functions and procedures
    ------------------------------------------------------------
    -- Logs the procedure call unless it is called from another
    -- procedure to avoid duplicate logs. It also generates the
    -- correct procedure call to be used for logging or alerts.
    procedure log_proc_call(
      constant msg_id          : in    t_msg_id;
      constant proc_call       : in    string;
      constant ext_proc_call   : in    string;
      variable new_proc_call   : inout line;
      constant msg_id_panel    : in    t_msg_id_panel) is
    begin
      -- Called directly from sequencer/VVC
      if ext_proc_call = "" then
        log(msg_id, proc_call, priv_scope.all, msg_id_panel);
        write(new_proc_call, proc_call);
      -- Called from another procedure
      else
        write(new_proc_call, ext_proc_call);
      end if;
    end procedure;

    -- Returns the string representation of the bin vector
    function to_string(
      bins : t_new_bin_vector)
    return string is
      variable v_line   : line;
      variable v_result : string(1 to 500);
      variable v_width  : natural;
    begin
      for i in bins'range loop
        case bins(i).contains is
          when VAL | VAL_IGNORE | VAL_ILLEGAL =>
            if bins(i).contains = VAL then
              write(v_line, string'("bin"));
            elsif bins(i).contains = VAL_IGNORE then
              write(v_line, string'("ignore_bin"));
            else
              write(v_line, string'("illegal_bin"));
            end if;
            if bins(i).num_values = 1 then
              write(v_line, '(');
              write(v_line, to_string(bins(i).values(0)));
              write(v_line, ')');
            else
              write(v_line, to_string(bins(i).values(0 to bins(i).num_values-1)));
            end if;
          when RAN | RAN_IGNORE | RAN_ILLEGAL =>
            if bins(i).contains = RAN then
              write(v_line, string'("bin_range"));
            elsif bins(i).contains = RAN_IGNORE then
              write(v_line, string'("ignore_bin_range"));
            else
              write(v_line, string'("illegal_bin_range"));
            end if;
            write(v_line, "(" & to_string(bins(i).values(0)) & " to " & to_string(bins(i).values(1)) & ")");
          when TRN =>
            write(v_line, string'("bin_transition("));
            for j in 0 to bins(i).num_values-1 loop
              write(v_line, to_string(bins(i).values(j)));
              if j < bins(i).num_values-1 then
                write(v_line, string'("->"));
              end if;
            end loop;
            write(v_line, ')');
        end case;
        if i < bins'length-1 then
          write(v_line, string'(","));
        end if;
      end loop;

      v_width := v_line'length;
      v_result(1 to v_width) := v_line.all;
      deallocate(v_line);
      return v_result(1 to v_width);
    end function;

    -- Returns the string representation of the bin content
    function to_string(
      bin_type       : t_cov_bin_type;
      bin_values     : integer_vector;
      bin_num_values : natural)
    return string is
      variable v_line   : line;
      variable v_result : string(1 to 100);
      variable v_width  : natural;
    begin
      write(v_line, '(');
      case bin_type is
        when VAL =>
          for i in 0 to bin_num_values-1 loop
            write(v_line, to_string(bin_values(i)));
            if i < bin_num_values-1 then
              write(v_line, string'(","));
            end if;
          end loop;
        when RAN =>
          write(v_line, to_string(bin_values(0)) & " to " & to_string(bin_values(1)));
        when TRN =>
          for i in 0 to bin_num_values-1 loop
            write(v_line, to_string(bin_values(i)));
            if i < bin_num_values-1 then
              write(v_line, string'("->"));
            end if;
          end loop;
        when others =>
          --TODO
      end case;
      write(v_line, ')');

      v_width := v_line'length;
      v_result(1 to v_width) := v_line.all;
      deallocate(v_line);
      return v_result(1 to v_width);
    end function;

    ------------------------------------------------------------
    -- Configuration
    ------------------------------------------------------------
    procedure set_scope(
      constant scope : in string) is
    begin
      DEALLOCATE(priv_scope);
      priv_scope := new string'(scope);
    end procedure;

    impure function get_scope(
      constant VOID : t_void)
    return string is
    begin
      return priv_scope.all;
    end function;

    ------------------------------------------------------------
    -- Bins
    ------------------------------------------------------------
    procedure add_bins(
      constant bin           : in t_new_bin_vector;
      constant min_cov       : in positive;
      constant rand_weight   : in natural;
      constant bin_name      : in string         := "";
      constant msg_id_panel  : in t_msg_id_panel := shared_msg_id_panel) is
      constant C_LOCAL_CALL : string := "add_bins(" & to_string(bin) & ", min_cov:" & to_string(min_cov) &
        ", rand_weight:" & to_string(rand_weight) & ", """ & bin_name & """)";
      variable v_proc_call : line;
    begin
      log_proc_call(ID_FUNCT_COV, C_LOCAL_CALL, "", v_proc_call, msg_id_panel); --TODO: check if replace for simple log
      for i in bin'range loop
        priv_bins(priv_bin_idx).contains       := bin(i).contains;
        priv_bins(priv_bin_idx).values         := bin(i).values;
        priv_bins(priv_bin_idx).num_values     := bin(i).num_values;
        priv_bins(priv_bin_idx).transition_idx := 0;
        priv_bins(priv_bin_idx).hits           := 0;
        priv_bins(priv_bin_idx).min_hits       := min_cov;
        priv_bins(priv_bin_idx).weight         := rand_weight;
        priv_bins(priv_bin_idx).name(1 to bin_name'length) := bin_name;
        priv_bin_idx := priv_bin_idx + 1;
      end loop;
    end procedure;

    procedure add_bins(
      constant bin           : in t_new_bin_vector;
      constant min_cov       : in positive;
      constant bin_name      : in string         := "";
      constant msg_id_panel  : in t_msg_id_panel := shared_msg_id_panel) is
    begin
      add_bins(bin, min_cov, 1, bin_name, msg_id_panel);
    end procedure;

    procedure add_bins(
      constant bin           : in t_new_bin_vector;
      constant bin_name      : in string         := "";
      constant msg_id_panel  : in t_msg_id_panel := shared_msg_id_panel) is
    begin
      add_bins(bin, 1, 1, bin_name, msg_id_panel);
    end procedure;

    ------------------------------------------------------------
    -- Randomization
    ------------------------------------------------------------
    impure function rand(
      constant msg_id_panel  : in t_msg_id_panel := shared_msg_id_panel)
    return integer is
      constant C_LOCAL_CALL      : string := "rand()";
      variable v_bin_weight_list : t_val_weight_int_vec(0 to priv_bin_idx-1);
      variable v_acc_weight      : integer := 0;
      variable v_values_vec      : integer_vector(0 to C_MAX_NUM_BIN_VALUES-1);
      variable v_bin_idx         : integer;
      variable v_ret             : integer;
    begin
      -- A transition bin returns all the transition values before allowing to select a different bin value
      if priv_rand_transition_bin_idx /= -1 then
        if priv_rand_transition_bin_value_idx < priv_bins(priv_rand_transition_bin_idx).num_values then
          v_ret := priv_bins(priv_rand_transition_bin_idx).values(priv_rand_transition_bin_value_idx);
          priv_rand_transition_bin_value_idx := priv_rand_transition_bin_value_idx + 1;
          log(ID_FUNCT_COV, C_LOCAL_CALL & " => " & to_string(v_ret), priv_scope.all, msg_id_panel);
          return v_ret;
        else
          priv_rand_transition_bin_idx := -1;
        end if;
      end if;

      -- Assign each bin a randomization weight
      for i in 0 to priv_bin_idx-1 loop
        v_bin_weight_list(i).value := i;
        if (priv_bins(i).contains = VAL or priv_bins(i).contains = RAN or priv_bins(i).contains = TRN) and priv_bins(i).hits < priv_bins(i).min_hits then
          v_bin_weight_list(i).weight := priv_bins(i).weight;
        else
          v_bin_weight_list(i).weight := 0;
        end if;
        v_acc_weight := v_acc_weight + v_bin_weight_list(i).weight;
      end loop;
      -- When all bins have reached their min_hits re-enable valid bins for selection
      if v_acc_weight = 0 then
        for i in 0 to priv_bin_idx-1 loop
          if (priv_bins(i).contains = VAL or priv_bins(i).contains = RAN or priv_bins(i).contains = TRN) then
            v_bin_weight_list(i).weight := priv_bins(i).weight;
          end if;
        end loop;
      end if;

      -- Choose a random bin index
      v_bin_idx := priv_rand_gen.rand_val_weight(v_bin_weight_list, msg_id_panel);

      -- Select the random bin value to return (ignore and illegal bin values are never selected)
      if priv_bins(v_bin_idx).contains = VAL then
        if priv_bins(v_bin_idx).num_values = 1 then
          v_ret := priv_bins(v_bin_idx).values(0);
        else
          for i in 0 to priv_bins(v_bin_idx).num_values-1 loop
            v_values_vec(i) := priv_bins(v_bin_idx).values(i);
          end loop;
          v_ret := priv_rand_gen.rand(ONLY, v_values_vec(0 to priv_bins(v_bin_idx).num_values-1), NON_CYCLIC, msg_id_panel);
        end if;
      elsif priv_bins(v_bin_idx).contains = RAN then
        v_ret := priv_rand_gen.rand(priv_bins(v_bin_idx).values(0), priv_bins(v_bin_idx).values(1), NON_CYCLIC, msg_id_panel);
      elsif priv_bins(v_bin_idx).contains = TRN then
        v_ret := priv_bins(v_bin_idx).values(0);
        priv_rand_transition_bin_value_idx := 1;
        priv_rand_transition_bin_idx := v_bin_idx;
      else
        alert(TB_FAILURE, C_LOCAL_CALL & " => Failed. Unexpected error.", priv_scope.all);
      end if;

      log(ID_FUNCT_COV, C_LOCAL_CALL & " => " & to_string(v_ret), priv_scope.all, msg_id_panel);
      return v_ret;
    end function;

    ------------------------------------------------------------
    -- Coverage
    ------------------------------------------------------------
    --Q: Do we need ignore bins? is it to show in some report how many hits some values we don't care got?
    --   OSVVM uses ignore bins when concatenating bins, e.g. CovBin2.AddBins( GenBin(1,2) & IgnoreBin(3,4) & GenBin(5,6) & ALL_ILLEGAL ) ;
    -- how does ALL work?
    --   SV uses ignore bins for automatically created bins (using a vector) to remove the unwanted values
    --   --> so if we generate bins with a big range or a vector, we can use ignore bins to remove them from the sampling
    procedure sample_coverage(
      constant value         : in integer;
      constant msg_id_panel  : in t_msg_id_panel := shared_msg_id_panel) is
    begin
      for i in 0 to priv_bin_idx-1 loop
        case priv_bins(i).contains is
          when VAL =>
            for j in 0 to priv_bins(i).num_values-1 loop
              if value = priv_bins(i).values(j) then
                priv_bins(i).hits := priv_bins(i).hits + 1;
              end if;
            end loop;
          when RAN =>
            if value >= priv_bins(i).values(0) and value <= priv_bins(i).values(1) then
              priv_bins(i).hits := priv_bins(i).hits + 1;
            end if;
          when TRN =>
            if value = priv_bins(i).values(priv_bins(i).transition_idx) then
              if priv_bins(i).transition_idx < priv_bins(i).num_values-1 then
                priv_bins(i).transition_idx := priv_bins(i).transition_idx + 1;
              else
                priv_bins(i).transition_idx := 0;
                priv_bins(i).hits           := priv_bins(i).hits + 1;
              end if;
            else
              priv_bins(i).transition_idx := 0;
            end if;
          when others =>
            --TODO: alert, this should never happen
        end case;
      end loop;
    end procedure;

    --Q: use same report as scoreboard?
    --Q: how to handle bins with several values? make COLUMN_WIDTH for BINS bigger than others - how big?, truncate and add "..."
    procedure print_summary(
      constant VOID : in t_void) is
      constant C_PREFIX          : string := C_LOG_PREFIX & "     ";
      constant C_HEADER          : string := "*** FUNCTIONAL COVERAGE SUMMARY: " & to_string(priv_scope.all) & " ***";
      constant C_COLUMN_WIDTH    : positive := 15;
      variable v_line            : line;
      variable v_line_copy       : line;
      variable v_log_extra_space : integer := 0;

      function is_bin_covered(bin : t_cov_bin) return string is
      begin
        if bin.hits >= bin.min_hits then
          return "YES";
        else
          return "NO";
        end if;
      end function;

      --TODO: move this function from scoreboard to another package to reuse
      -- add simulation time stamp to scoreboard report header
      impure function timestamp_header(value : time; txt : string) return string is
          variable v_line             : line;
          variable v_delimiter_pos    : natural;
          variable v_timestamp_width  : natural;
          variable v_result           : string(1 to 50);
          variable v_return           : string(1 to txt'length) := txt;
        begin
          -- get a time stamp
          write(v_line, value, LEFT, 0, C_LOG_TIME_BASE);
          v_timestamp_width := v_line'length;
          v_result(1 to v_timestamp_width) := v_line.all;
          deallocate(v_line);
          v_delimiter_pos := pos_of_leftmost('.', v_result(1 to v_timestamp_width), 0);

          -- truncate decimals and add units
          if v_delimiter_pos > 0 then
            if C_LOG_TIME_BASE = ns then
              v_result(v_delimiter_pos+2 to v_delimiter_pos+4) := " ns";
            else
              v_result(v_delimiter_pos+2 to v_delimiter_pos+4) := " ps";
            end if;
            v_timestamp_width := v_delimiter_pos + 4;
          end if;
          -- add a space after the timestamp
          v_timestamp_width := v_timestamp_width + 1;
          v_result(v_timestamp_width to v_timestamp_width) := " ";

          -- add time string to return string
          v_return := v_result(1 to v_timestamp_width) & txt(1 to txt'length-v_timestamp_width);
          return v_return(1 to txt'length);
        end function timestamp_header;

    begin

      -- Calculate how much space we can insert between the columns of the report
      v_log_extra_space := (C_LOG_LINE_WIDTH - C_PREFIX'length - C_COLUMN_WIDTH*5 - C_MAX_BIN_NAME_LENGTH - 20)/6;
      if v_log_extra_space < 1 then
        alert(TB_WARNING, "C_LOG_LINE_WIDTH is too small or C_MAX_BIN_NAME_LENGTH is too big, the report will not be properly aligned.", priv_scope.all);
        v_log_extra_space := 1;
      end if;

      -- Print report header
      write(v_line, LF & fill_string('=', (C_LOG_LINE_WIDTH - C_PREFIX'length)) & LF &
                    timestamp_header(now, justify(C_HEADER, LEFT, C_LOG_LINE_WIDTH - C_PREFIX'length, SKIP_LEADING_SPACE, DISALLOW_TRUNCATE)) & LF &
                    fill_string('=', (C_LOG_LINE_WIDTH - C_PREFIX'length)) & LF);

      -- Print column headers
      write(v_line, justify(
        fill_string(' ', 5) &
        justify("BINS"     , center, C_COLUMN_WIDTH, SKIP_LEADING_SPACE, DISALLOW_TRUNCATE) & fill_string(' ', v_log_extra_space) &
        justify("HITS"     , center, C_COLUMN_WIDTH, SKIP_LEADING_SPACE, DISALLOW_TRUNCATE) & fill_string(' ', v_log_extra_space) &
        justify("MIN_HITS" , center, C_COLUMN_WIDTH, SKIP_LEADING_SPACE, DISALLOW_TRUNCATE) & fill_string(' ', v_log_extra_space) &
        justify("WEIGHT"   , center, C_COLUMN_WIDTH, SKIP_LEADING_SPACE, DISALLOW_TRUNCATE) & fill_string(' ', v_log_extra_space) &
        justify("NAME"     , center, C_MAX_BIN_NAME_LENGTH, SKIP_LEADING_SPACE, DISALLOW_TRUNCATE) & fill_string(' ', v_log_extra_space) &
        justify("COVERED"  , center, C_COLUMN_WIDTH, SKIP_LEADING_SPACE, DISALLOW_TRUNCATE) & fill_string(' ', v_log_extra_space),
        left, C_LOG_LINE_WIDTH - C_PREFIX'length, KEEP_LEADING_SPACE, DISALLOW_TRUNCATE) & LF);

      -- Print bins
      for i in 0 to priv_bin_idx-1 loop
        if (priv_bins(i).contains = VAL or priv_bins(i).contains = RAN or priv_bins(i).contains = TRN) then
          write(v_line, justify(
            fill_string(' ', 5) &
            justify(to_string(priv_bins(i).contains, priv_bins(i).values, priv_bins(i).num_values), center, C_COLUMN_WIDTH, SKIP_LEADING_SPACE, DISALLOW_TRUNCATE) & fill_string(' ', v_log_extra_space) &
            justify(to_string(priv_bins(i).hits)     , center, C_COLUMN_WIDTH, SKIP_LEADING_SPACE, DISALLOW_TRUNCATE) & fill_string(' ', v_log_extra_space) &
            justify(to_string(priv_bins(i).min_hits) , center, C_COLUMN_WIDTH, SKIP_LEADING_SPACE, DISALLOW_TRUNCATE) & fill_string(' ', v_log_extra_space) &
            justify(to_string(priv_bins(i).weight)   , center, C_COLUMN_WIDTH, SKIP_LEADING_SPACE, DISALLOW_TRUNCATE) & fill_string(' ', v_log_extra_space) &
            justify(to_string(priv_bins(i).name)     , center, C_MAX_BIN_NAME_LENGTH, SKIP_LEADING_SPACE, DISALLOW_TRUNCATE) & fill_string(' ', v_log_extra_space) &
            justify(is_bin_covered(priv_bins(i))     , center, C_COLUMN_WIDTH, SKIP_LEADING_SPACE, DISALLOW_TRUNCATE) & fill_string(' ', v_log_extra_space),
            left, C_LOG_LINE_WIDTH - C_PREFIX'length, KEEP_LEADING_SPACE, DISALLOW_TRUNCATE) & LF);
        end if;
      end loop;

      -- Print report bottom line
      write(v_line, fill_string('=', (C_LOG_LINE_WIDTH - C_PREFIX'length)) & LF & LF);
      wrap_lines(v_line, 1, 1, C_LOG_LINE_WIDTH-C_PREFIX'length);
      prefix_lines(v_line, C_PREFIX);

      -- Write the info string to transcript
      write (v_line_copy, v_line.all);  -- copy line
      writeline(OUTPUT, v_line);
      writeline(LOG_FILE, v_line_copy);
      deallocate(v_line);
      deallocate(v_line_copy);
    end procedure;

  end protected body t_cov_point;

end package body funct_cov_pkg;