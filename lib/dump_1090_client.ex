defmodule Dump1090Client do
  require Logger

  def start_listener() do
    children = [
      {
        Dump1090Client.Network.Client, [
          host: Application.get_env(:dump_1090_client, :address),
          port: Application.get_env(:dump_1090_client, :port)
        ]
      }
    ]

    {:ok, _pid} = Tortoise.Connection.start_link(
      client_id: "dump_1090_client",
      server: {Tortoise.Transport.Tcp, host: "localhost", port: 1883},
      handler: {Tortoise.Handler.Logger, []}
    )

    opts = [strategy: :one_for_one, name: Dump1090Client.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def replay_from_file(file_name, delay) do
    Task.async(fn ->
      File.stream!(file_name)
        |> Stream.map(fn(msg) ->
          Tortoise.publish(
            "dump_1090_client",
            Aircraft.raw_adsb_topic,
            msg)
          case Aircraft.ParseAdsb.parse(msg) do
            aircraft = %Aircraft{icoa: _icoa} ->
              {:ok, data} = JSON.encode(aircraft)
              Tortoise.publish(
                "dump_1090_client",
                Aircraft.update_topic,
                data
              )
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
