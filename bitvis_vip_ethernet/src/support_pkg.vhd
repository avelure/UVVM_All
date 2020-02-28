--================================================================================================================================
-- Copyright (c) 2020 by Bitvis AS.  All rights reserved.
-- You should have received a copy of the license file containing the MIT License (see LICENSE.TXT), if not,
-- contact Bitvis AS <support@bitvis.no>.
--
-- UVVM AND ANY PART THEREOF ARE PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
-- THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS
-- OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
-- OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH UVVM OR THE USE OR OTHER DEALINGS IN UVVM.
--================================================================================================================================

---------------------------------------------------------------------------------------------
-- Description : See library quick reference (under 'doc') and README-file(s)
---------------------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

--========================================================================================================================
--========================================================================================================================
package support_pkg is

  --========================================================================================================================
  -- Types and constants
  --========================================================================================================================
  constant C_PREAMBLE           : std_logic_vector(55 downto 0) := x"55_55_55_55_55_55_55";
  constant C_SFD                : std_logic_vector( 7 downto 0) := x"D5";

  constant C_MIN_PAYLOAD_LENGTH : natural := 46;
  constant C_MAX_PAYLOAD_LENGTH : natural := 1500;
  constant C_MAX_FRAME_LENGTH   : natural := C_MAX_PAYLOAD_LENGTH + 18;
  constant C_MAX_PACKET_LENGTH  : natural := C_MAX_FRAME_LENGTH + 8;

  -- IF field index config
  constant C_ETHERNET_FIELD_IDX_PREAMBLE_SFD    : natural := 0;
  constant C_ETHERNET_FIELD_IDX_MAC_DESTINATION : natural := 1;
  constant C_ETHERNET_FIELD_IDX_MAC_SOURCE      : natural := 2;
  constant C_ETHERNET_FIELD_IDX_LENGTH          : natural := 3;
  constant C_ETHERNET_FIELD_IDX_PAYLOAD         : natural := 4;
  constant C_ETHERNET_FIELD_IDX_FCS             : natural := 5;

  type t_ethernet_frame is record
    mac_destination : unsigned(47 downto 0);
    mac_source      : unsigned(47 downto 0);
    length          : integer;
    payload         : t_byte_array(0 to C_MAX_PAYLOAD_LENGTH-1);
    fcs             : std_logic_vector(31 downto 0);
  end record t_ethernet_frame;

  constant C_ETHERNET_FRAME_DEFAULT : t_ethernet_frame := (
    mac_destination => (others => '0'),
    mac_source      => (others => '0'),
    length          => 0,
    payload         => (others => (others => '0')),
    fcs             => (others => '0'));

  type t_ethernet_frame_status is record
    fcs_error : boolean;
  end record t_ethernet_frame_status;

  -- Configuration record to be assigned in the test harness
  type t_ethernet_protocol_config is record
    mac_destination      : unsigned(47 downto 0);
    mac_source           : unsigned(47 downto 0);
    fcs_error_severity   : t_alert_level;
    interpacket_gap_time : time;
  end record;

  constant C_ETHERNET_PROTOCOL_CONFIG_DEFAULT : t_ethernet_protocol_config := (
    mac_destination      => (others => '0'),
    mac_source           => (others => '0'),
    fcs_error_severity   => ERROR,
    interpacket_gap_time => 96 ns -- Standard minimum interpacket gap (Gigabith Ethernet)
  );


  --========================================================================================================================
  -- Functions and procedures
  --========================================================================================================================
  impure function generate_crc_32(
    constant data_array : in t_byte_array
  ) return std_logic_vector;

  impure function check_crc_32(
    constant data_array : in t_byte_array
  ) return boolean;

  function get_ethernet_frame_length(
    constant payload_length : in positive
  ) return positive;

  function to_string(
    constant ethernet_frame : in t_ethernet_frame
  ) return string;

  function to_string(
    constant ethernet_frame : in t_ethernet_frame;
    constant frame_field    : in t_frame_field
  ) return string;

  function to_slv(
    constant byte_array : in t_byte_array
  ) return std_logic_vector;

  function to_byte_array(
    constant data : in std_logic_vector
  ) return t_byte_array;

  procedure compare_ethernet_frames(
    constant actual       : in t_ethernet_frame;
    constant expected     : in t_ethernet_frame;
    constant alert_level  : in t_alert_level;
    constant msg          : in string;
    constant scope        : in string;
    constant msg_id_panel : in t_msg_id_panel;
    constant proc_call    : in string
  );

  impure function compare_ethernet_frames(
    constant actual       : in t_ethernet_frame;
    constant expected     : in t_ethernet_frame;
    constant alert_level  : in t_alert_level;
    constant msg          : in string;
    constant scope        : in string;
    constant msg_id_panel : in t_msg_id_panel;
    constant proc_call    : in string
  ) return boolean;

  function ethernet_match(
    constant actual   : in t_ethernet_frame;
    constant expected : in t_ethernet_frame
  ) return boolean;

end package support_pkg;


--========================================================================================================================
--========================================================================================================================

package body support_pkg is

  -- Generates the IEEE 802.3 CRC32 for byte array input
  impure function generate_crc_32(
    constant data_array : in t_byte_array
  ) return std_logic_vector is
  begin
    return generate_crc(data_array, C_CRC_32_START_VALUE, C_CRC_32_POLYNOMIAL);
  end function generate_crc_32;

  impure function check_crc_32(
    constant data_array : in t_byte_array
  ) return boolean is
  begin
    return generate_crc_32(data_array) = C_CRC_32_RESIDUE;
  end function check_crc_32;

  -- Returns the complete frame length
  function get_ethernet_frame_length(
    constant payload_length : in positive
  ) return positive is
  begin
    return payload_length + 18;
  end function get_ethernet_frame_length;

  function to_string(
    constant ethernet_frame : in t_ethernet_frame
  ) return string is
  begin
    return "MAC dest: "  & to_string(ethernet_frame.mac_destination, HEX, AS_IS, INCL_RADIX) &
           ", MAC src: " & to_string(ethernet_frame.mac_source, HEX, AS_IS, INCL_RADIX) &
           ", length: "  & to_string(ethernet_frame.length) &
           ", fcs: "     & to_string(ethernet_frame.fcs, HEX, AS_IS, INCL_RADIX);
  end function to_string;

  function to_string(
    constant ethernet_frame : in t_ethernet_frame;
    constant frame_field    : in t_frame_field
  ) return string is
    variable payload_string : string(1 to 14*ethernet_frame.length); --[1500]:x"00",
    variable v_line         : line;
    variable v_line_width   : natural;
  begin
    case frame_field is
      when HEADER =>
        return LF & "    MAC destination: " & to_string(ethernet_frame.mac_destination, HEX, KEEP_LEADING_0, INCL_RADIX) &
               LF & "    MAC source:      " & to_string(ethernet_frame.mac_source, HEX, KEEP_LEADING_0, INCL_RADIX) &
               LF & "    length:          " & to_string(ethernet_frame.length);

      when PAYLOAD =>
        write(v_line, string'("[" & to_string(0) & "]:" & to_string(ethernet_frame.payload(0), HEX, AS_IS, INCL_RADIX)));
        if ethernet_frame.length > 1 then
          for i in 1 to ethernet_frame.length-1 loop
            write(v_line, string'(", [" & to_string(i) & "]:" & to_string(ethernet_frame.payload(i), HEX, AS_IS, INCL_RADIX)));
          end loop;
        end if;
        v_line_width := v_line'length;
        payload_string(1 to v_line_width) := v_line.all;
        deallocate(v_line);
        return LF & payload_string(1 to v_line_width);

      when CHECKSUM =>
        return LF & "    FCS: " & to_string(ethernet_frame.fcs, HEX, AS_IS, INCL_RADIX);

      when others =>
        return "";
    end case;
  end function to_string;

  function to_slv(
    constant byte_array : in t_byte_array
  ) return std_logic_vector is
    constant C_NUM_BYTES           : integer := byte_array'length;
    variable normalized_byte_array : t_byte_array(0 to C_NUM_BYTES-1) ;
    variable v_return_val          : std_logic_vector(8*C_NUM_BYTES-1 downto 0);
  begin
    normalized_byte_array := byte_array;
    for i in 0 to C_NUM_BYTES-1 loop
      v_return_val(8*(C_NUM_BYTES-i)-1 downto 8*(C_NUM_BYTES-i-1)) := normalized_byte_array(i);
    end loop;
    return v_return_val;
  end function to_slv;

  function get_num_bytes(
    constant num_bits : in positive
  ) return positive is
    variable v_num_bytes : positive;
  begin
    v_num_bytes := num_bits/8;
    if (num_bits rem 8) /= 0 then
      v_num_bytes := v_num_bytes+1;
    end if;
    return v_num_bytes;
  end function get_num_bytes;

  function to_byte_array(
    constant data : in std_logic_vector
  ) return t_byte_array is
    alias    normalized_data : std_logic_vector(data'length-1 downto 0) is data;
    constant C_NUM_BYTES     : positive := get_num_bytes(data'length);
    variable v_byte_array    : t_byte_array(0 to C_NUM_BYTES-1);
    variable v_bit_idx       : integer := normalized_data'high;
  begin
    for byte_idx in 0 to C_NUM_BYTES-1 loop
      for i in 7 downto 0 loop
        if v_bit_idx = -1 then
          v_byte_array(byte_idx)(i) := 'Z'; -- Pads 'Z'
        else
          v_byte_array(byte_idx)(i) := normalized_data(v_bit_idx);
          v_bit_idx := v_bit_idx-1;
        end if;
      end loop;
    end loop;
    return v_byte_array;
  end function to_byte_array;

  procedure compare_ethernet_frames(
    constant actual       : in t_ethernet_frame;
    constant expected     : in t_ethernet_frame;
    constant alert_level  : in t_alert_level;
    constant msg          : in string;
    constant scope        : in string;
    constant msg_id_panel : in t_msg_id_panel;
    constant proc_call    : in string
  ) is
  begin
    check_value(actual.mac_destination, expected.mac_destination, alert_level, "Verify MAC destination"              & LF & msg, scope, HEX, KEEP_LEADING_0, ID_PACKET_HDR,  msg_id_panel, proc_call);
    check_value(actual.mac_source,      expected.mac_source,      alert_level, "Verify MAC source"                   & LF & msg, scope, HEX, KEEP_LEADING_0, ID_PACKET_HDR,  msg_id_panel, proc_call);
    check_value(actual.length,          expected.length,          alert_level, "Verify length"                       & LF & msg, scope,                      ID_PACKET_HDR,  msg_id_panel, proc_call);
    for i in 0 to actual.length-1 loop
      check_value(actual.payload(i),    expected.payload(i),      alert_level, "Verify payload byte " & to_string(i) & LF & msg, scope, HEX, KEEP_LEADING_0, ID_PACKET_DATA, msg_id_panel, proc_call);
    end loop;
    check_value(actual.fcs,             expected.fcs,             alert_level, "Verify FCS"                          & LF & msg, scope, HEX, KEEP_LEADING_0, ID_PACKET_DATA, msg_id_panel, proc_call);
  end procedure compare_ethernet_frames;

  impure function compare_ethernet_frames(
    constant actual       : in t_ethernet_frame;
    constant expected     : in t_ethernet_frame;
    constant alert_level  : in t_alert_level;
    constant msg          : in string;
    constant scope        : in string;
    constant msg_id_panel : in t_msg_id_panel;
    constant proc_call    : in string
  ) return boolean is
  begin
    if not check_value(actual.mac_destination, expected.mac_destination, alert_level, "Verify MAC destination" & LF & msg, scope, HEX, KEEP_LEADING_0, ID_NEVER, msg_id_panel, proc_call) then
      return false;
    end if;
    if not check_value(actual.mac_source, expected.mac_source, alert_level, "Verify MAC source" & LF & msg, scope, HEX, KEEP_LEADING_0, ID_NEVER, msg_id_panel, proc_call) then
      return false;
    end if;
    if not check_value(actual.length, expected.length, alert_level, "Verify length" & LF & msg, scope, ID_NEVER, msg_id_panel, proc_call) then
      return false;
    end if;
    for i in 0 to actual.length-1 loop
      if not check_value(actual.payload(i), expected.payload(i), alert_level, "Verify payload byte " & to_string(i) & LF & msg, scope, HEX, KEEP_LEADING_0, ID_NEVER, msg_id_panel, proc_call) then
        return false;
      end if;
    end loop;
    if not check_value(actual.fcs, expected.fcs, alert_level, "Verify FCS" & LF & msg, scope, HEX, KEEP_LEADING_0, ID_NEVER, msg_id_panel, proc_call) then
      return false;
    end if;
    return true;
  end function compare_ethernet_frames;

  function ethernet_match(
    constant actual   : in t_ethernet_frame;
    constant expected : in t_ethernet_frame
  ) return boolean is
  begin
    return actual.mac_destination               = expected.mac_destination                 and
           actual.mac_source                    = expected.mac_source                      and
           actual.length                        = expected.length                          and
           actual.payload(0 to actual.length-1) = expected.payload(0 to expected.length-1) and
           actual.fcs                           = expected.fcs;
  end function ethernet_match;

end package body support_pkg;