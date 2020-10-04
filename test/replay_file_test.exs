defmodule ReplayFileTest do
  use ExUnit.Case, async: true

  test "reply from file" do

    Dump1090Client.replay_from_file "./test/data/replay_file", 0

    assert_receive {:raw, "MSG,1,111,11111,A44728,111111,2018/11/17,21:33:06.976,2018/11/17,21:33:06.938,JBU1616 ,,,,,,,,,,,0\n"}, 100
    assert_receive {:update, %Aircraft{
      altitude: nil,
      callsign: "JBU1616",
      heading: nil,
      icoa: "A44728",
      last_seen_time: nil,
      latitude: nil,
      longitude: nil,
      speed: nil
    }}, 100

    assert_receive {:raw, "MSG,3,,,AADFF1,,,,,,,40000,,,42.49749,-71.02463,,,0,0,0,0\n"}, 100
    assert_receive {:update, %Aircraft{
      altitude: 40000,
      callsign: nil,
      heading: nil,
      icoa: "AADFF1",
      last_seen_time: nil,
      latitude: 42.49749,
      longitude: -71.02463,
      speed: nil
    }}, 100

    assert_receive {:raw, "MSG,4,,,A77C11,,,,,,,,397,251,,,0,,0,0,0,0\n"}, 100
    assert_receive {:update, %Aircraft{
      altitude: nil,
      callsign: nil,
      heading: 251,
      icoa: "A77C11",
      last_seen_time: nil,
      latitude: nil,
      longitude: nil,
      speed: 397
    }}, 100

    assert_receive {:raw, "Oops\n"}, 100
  end

end
