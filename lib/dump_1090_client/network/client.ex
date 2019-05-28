defmodule Dump1090Client.Network.Client do
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    state = opts_to_initial_state(opts)
    connect(state)
  end

  def status() do
    GenServer.call(Dump1090Client.Network.Client, :status)
  end

  defp connect(state) do
    case :gen_tcp.connect(state.host, state.port, []) do
      {:ok, _socket} ->
        state.on_connect.(state)
        new_state = %{state | connected: true}
        {:ok, new_state}
      {:error, _reason} ->
        new_state = %{state | failure_count: 1, connected: false}
        new_state.on_disconnect.(new_state)
        {:ok, new_state, state.retry_interval}
    end
  end

  def handle_call(:status, _from, state) do
    endpoint = to_string(state.host) <> ":" <> to_string(state.port)
    reply = %{
      connected: state.connected,
      address: endpoint
    }
    {:reply, reply, state}
  end

  def handle_info({:tcp, _socket, message}, state) do
    Enum.each(String.split(List.to_string(message), "\r\n"), fn (msg) ->
      case String.length msg do
        0 ->
          nil
        _ ->
          Phoenix.PubSub.broadcast(Aircraft.channel, Aircraft.raw_adsb_topic, {:raw, msg})
          case Aircraft.ParseAdsb.parse(msg) do
            aircraft = %Aircraft{icoa: _icoa} ->
              Phoenix.PubSub.broadcast(Aircraft.channel, Aircraft.update_topic, {:update, aircraft})
            _ ->
              :ok
          end
      end
    end)
    {:noreply, state}
  end

  def handle_info(:timeout, state = %{failure_count: failure_count}) do
    if failure_count <= state.max_retries do
      case :gen_tcp.connect(state.host, state.port, []) do
        {:ok, _socket} ->
          new_state = %{state | failure_count: 0, connected: true}
          new_state.on_connect.(new_state)
          {:noreply, new_state}
        {:error, _reason} ->
          new_state = %{state | failure_count: failure_count + 1, connected: false}
          new_state.on_disconnect.(new_state)
          :timer.sleep(state.retry_delay)
          {:noreply, new_state, state.retry_interval}
      end
    else
      state.on_retries_exceeded.(state)
      {:stop, :max_retry_exceeded, state}
    end
  end

  def handle_info({:tcp_closed, _socket}, state) do
    {:noreply, state}
  end

  defp opts_to_initial_state(opts) do
    state = %{
      host: '127.0.0.1',
      port: 30003,
      max_retries: 60,
      retry_interval: 60_000,
      retry_delay: 1_000,
      failure_count: 0,
      connected: false,
      on_connect: fn state ->
        Logger.info("tcp connect to #{state.host}:#{state.port}", ansi_color: :light_blue)
      end,
      on_disconnect: fn state ->
        Logger.info("tcp disconnect from #{state.host}:#{state.port}", ansi_color: :light_blue)
      end,
      on_retries_exceeded: fn state ->
        Logger.info("Max retries exceeded for #{state.host}:#{state.port}.")
      end,
    }

    state = if Keyword.has_key?(opts, :host) do
      %{ state | host: Keyword.get(opts, :host, "localhost") |> String.to_charlist }
    else
      state
    end

    state = if Keyword.has_key?(opts, :port) do
      %{ state | port: Keyword.fetch!(opts, :port) }
    else
      state
    end

    state = if Keyword.has_key?(opts, :max_retries) do
      %{ state | max_retries: Keyword.fetch!(opts, :max_retries) }
    else
      state
    end

    state = if Keyword.has_key?(opts, :retry_interval) do
      %{ state | retry_interval: Keyword.fetch!(opts, :retry_interval) }
    else
      state
    end

    state = if Keyword.has_key?(opts, :retry_delay) do
      %{ state | retry_delay: Keyword.fetch!(opts, :retry_delay) }
    else
      state
    end

    state
  end

end
