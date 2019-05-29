defmodule Dump1090Client do
  require Logger

  def start_listener() do
    children = [
      {Dump1090Client.Network.Client, [
        host: Application.get_env(:dump_1090_client, :address),
        port: Application.get_env(:dump_1090_client, :port)
      ]}
    ]

    opts = [strategy: :one_for_one, name: Dump1090Client.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def replay_from_file(file_name, delay) do
    Task.async(fn ->
      File.stream!(file_name)
        |> Stream.map(fn(msg) ->
          Phoenix.PubSub.broadcast(Aircraft.channel, Aircraft.raw_adsb_topic, {:raw, msg})
          case Aircraft.ParseAdsb.parse(msg) do
            aircraft = %Aircraft{icoa: _icoa} ->
              Phoenix.PubSub.broadcast(Aircraft.channel, Aircraft.update_topic, {:update, aircraft})
            :not_supported ->
              :ok
          end
          :timer.sleep(delay)
        end)
        |> Stream.run
    end)
  end

  def status() do
    Dump1090Client.Network.Client.status()
  end
end
