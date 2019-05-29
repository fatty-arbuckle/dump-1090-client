defmodule ClientTest do
  use ExUnit.Case, async: false

  test "that client connects and broadcasts messages" do
    Phoenix.PubSub.subscribe Aircraft.channel, Aircraft.raw_adsb_topic
    Phoenix.PubSub.subscribe Aircraft.channel, Aircraft.update_topic
    server = Task.async(fn ->
      {:ok, listener} = :gen_tcp.listen(30123, [packet: :line, active: false, reuseaddr: true])
      {:ok, socket} = :gen_tcp.accept(listener, 5000)
      :gen_tcp.send(socket, "MSG,1,111,11111,A44728,111111,2018/11/17,21:33:06.976,2018/11/17,21:33:06.938,JBU1616 ,,,,,,,,,,,0\n")
      :gen_tcp.close(socket)
    end)
    {:ok, _client} = Dump1090Client.Network.Client.start_link [host: "127.0.0.1", port: 30123]
    status = Dump1090Client.status()
    assert Map.has_key?(status, :address)
    assert Map.get(status, :address) == "127.0.0.1:30123"
    Task.await(server)
    assert_receive {:raw, "MSG,1,111,11111,A44728,111111,2018/11/17,21:33:06.976,2018/11/17,21:33:06.938,JBU1616 ,,,,,,,,,,,0\n"}, 1000
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
  end

  test "that client connects after failing first" do
    Phoenix.PubSub.subscribe Aircraft.channel, Aircraft.raw_adsb_topic
    Phoenix.PubSub.subscribe Aircraft.channel, Aircraft.update_topic
    {:ok, _client} = Dump1090Client.Network.Client.start_link [
      host: "127.0.0.1",
      port: 30998,
      max_retries: 10,
      retry_interval: 100
    ]
    server = Task.async(fn ->
      {:ok, listener} = :gen_tcp.listen(30998, [packet: :line, active: false, reuseaddr: true])
      {:ok, socket} = :gen_tcp.accept(listener, 5000)
      :timer.sleep(100)
      :gen_tcp.send(socket, "MSG,1,111,11111,A44728,111111,2018/11/17,21:33:06.976,2018/11/17,21:33:06.938,JBU1616 ,,,,,,,,,,,0\n")
      :gen_tcp.close(socket)
    end)
    Task.await(server)
    assert_receive {:raw, "MSG,1,111,11111,A44728,111111,2018/11/17,21:33:06.976,2018/11/17,21:33:06.938,JBU1616 ,,,,,,,,,,,0\n"}, 1000
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
  end

  test "that client gives up when it cannot connect after retrying" do
    Process.flag :trap_exit, true
    {:ok, _client} = Dump1090Client.Network.Client.start_link [
      host: "127.0.0.1",
      port: 30999,
      max_retries: 2,
      retry_interval: 100
    ]
    receive do
      {:EXIT, _from, reason} ->
        assert reason == :max_retry_exceeded
    end
  end

  test "that client sets all of the defaults correctly" do
    Process.flag :trap_exit, true
    {:ok, _client} = Dump1090Client.Network.Client.start_link [
      max_retries: 2,
      retry_interval: 100
    ]
    receive do
      {:EXIT, _from, reason} ->
        assert reason == :max_retry_exceeded
    end
  end

  # test "application starts client" do
  #   Dump1090Client.Application.start nil, nil
  #   {:error, {:already_started, _pid}} = Dump1090Client.Network.Client.start_link []
  # end

  test "client uses default when hostname and port are nil" do
    {:ok, _client} = Dump1090Client.Network.Client.start_link [
      host: nil,
      port: nil
    ]
    assert %{address: "127.0.0.1:30003", connected: false}  == Dump1090Client.status()

  end


end
