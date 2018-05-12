defmodule NervesRpi3WifiPicam do
  @moduledoc """
  Documentation for NervesRpi3WifiPicam.
  """

  @doc """
  Hello world.

  ## Examples

      iex> NervesRpi3WifiPicam.hello
      :world

  """
  def hello do
    :world
  end

  def take_and_read_picture() do
    Picam.Camera.start_link

    Picam.next_frame
    |> Base.encode64()
    |> IO.puts()
  end
end
