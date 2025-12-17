defmodule DeskBuddy.State do
  use GenServer

  @tick_ms 5_000

  defstruct [
    :mood,
    :energy,
    :attention,
    :born_at,
    :last_interaction,
    :personality
  ]

  ## Public API

  def start_link(_),
    do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  def interact,
    do: GenServer.cast(__MODULE__, :interact)

  def rest,
    do: GenServer.cast(__MODULE__, :rest)

  ## GenServer

  def init(_) do
    state = %__MODULE__{
      mood: :happy,
      energy: 80,
      attention: 80,
      born_at: now(),
      last_interaction: now(),
      personality: Enum.random([:needy, :chill, :grumpy])
    }

    schedule_tick()
    {:ok, state}
  end

  def handle_cast(:interact, state) do
    state =
      state
      |> touch()
      |> inc(:attention, 15)
      |> inc(:energy, 5)

    {:noreply, update_mood(state)}
  end

  def handle_cast(:rest, state) do
    state =
      state
      |> inc(:energy, 20)
      |> dec(:attention, 5)

    {:noreply, update_mood(state)}
  end

  def handle_info(:tick, state) do
    state =
      state
      |> dec(:energy, 3)
      |> dec(:attention, attention_decay(state))
      |> update_mood()

    DeskBuddy.Render.render(state)
    schedule_tick()
    {:noreply, state}
  end

  ## Helpers

  defp schedule_tick,
    do: Process.send_after(self(), :tick, @tick_ms)

  defp update_mood(state) do
    cond do
      state.energy < 20 -> %{state | mood: :sleepy}
      state.attention < 20 -> %{state | mood: :bored}
      state.attention > 80 and state.energy > 60 -> %{state | mood: :happy}
      true -> %{state | mood: :grumpy}
    end
  end

  defp attention_decay(%{personality: :needy}), do: 6
  defp attention_decay(%{personality: :grumpy}), do: 4
  defp attention_decay(_), do: 2

  defp inc(state, key, v),
    do: Map.update!(state, key, &min(&1 + v, 100))

  defp dec(state, key, v),
    do: Map.update!(state, key, &max(&1 - v, 0))

  defp touch(state),
    do: %{state | last_interaction: now()}

  defp now, do: System.system_time(:second)
end
