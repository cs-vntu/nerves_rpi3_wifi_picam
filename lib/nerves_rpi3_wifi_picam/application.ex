defmodule NervesRpi3WifiPicam.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  @target Mix.Project.config()[:target]

  use Application

  def start(_type, _args) do
    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options

    Picam.Camera.start_link
    opts = [strategy: :one_for_one, name: NervesRpi3WifiPicam.Supervisor]
    Supervisor.start_link(children(@target), opts)
  end

  # List all child processes to be supervised
  def children("host") do
    [
      # Starts a worker by calling: NervesRpi3WifiPicam.Worker.start_link(arg)
      # {NervesRpi3WifiPicam.Worker, arg},
    ]
  end

  def children(_target) do
    [
      Plug.Adapters.Cowboy.child_spec(scheme: :http, plug: NervesRpi3WifiPicam.Router, options: [port: 4001])
    ]
  end
end
