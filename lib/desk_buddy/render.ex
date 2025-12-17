defmodule DeskBuddy.Render do
  use GenServer

  def start_link(_),
    do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  def init(_) do
    port =
      Port.open(
        {:spawn, "python3 /usr/local/bin/display.py"},
        [:binary, packet: 4]
      )

    {:ok, port}
  end

  def render(state),
    do: GenServer.cast(__MODULE__, {:render, state})

  def handle_cast({:render, state}, port) do
    payload = %{
      mood: state.mood,
      energy: state.energy,
      attention: state.attention
    }

    Port.command(port, Jason.encode!(payload))
    {:noreply, port}
  end
end
