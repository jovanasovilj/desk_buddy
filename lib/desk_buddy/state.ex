defmodule DeskBuddy.State do
  use GenServer
  require Logger

  @tick_ms 3_000

  defstruct [
    :mood,
    :energy,
    :attention,
    :born_at,
    :last_interaction,
    :personality,
    :tick_count
  ]

  ## Public API

  def start_link(_),
    do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  def set_personality(p) when p in [:chill, :needy, :grumpy],
    do: GenServer.cast(__MODULE__, {:set_personality, p})

  def interact,
    do: GenServer.cast(__MODULE__, :interact)

  def rest,
    do: GenServer.cast(__MODULE__, :rest)

  ## GenServer

  @impl true
  def init(_) do
    # Personality is set through an environment variable on init (chill | grumpy | needy)
    personality =
      System.get_env("DESK_BUDDY_PERSONALITY", "chill")
      |> String.to_atom()

    mood =
      case personality do
        :grumpy -> :grumpy
        _ -> :happy
      end

    state = %__MODULE__{
      mood: mood,
      energy: 80,
      attention: 80,
      born_at: now(),
      last_interaction: now(),
      personality: personality,
      tick_count: 0
    }

    DeskBuddy.Display.fill(color_for(state.mood))

    log_status(state, "boot")

    schedule_tick()
    {:ok, state}
  end

  @impl true
  def handle_cast({:set_personality, personality}, state) do
    prev_mood = state.mood

    state =
      state
      |> Map.put(:personality, personality)
      |> update_mood()

    DeskBuddy.Display.fill(color_for(state.mood))
    log_status(state, "personality_change")

    if state.mood != prev_mood do
      log_status(state, "mood_change")
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast(:interact, state) do
    prev_mood = state.mood

    state =
      state
      |> touch()
      |> inc(:attention, 15)
      |> inc(:energy, 5)
      |> update_mood()

    if state.mood != prev_mood do
      DeskBuddy.Display.fill(color_for(state.mood))
      log_status(state, "interact")
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast(:rest, state) do
    prev_mood = state.mood

    state =
      state
      |> inc(:energy, 20)
      |> dec(:attention, 5)
      |> update_mood()

    if state.mood != prev_mood do
      DeskBuddy.Display.fill(color_for(state.mood))
      log_status(state, "rest")
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(:tick, state) do
    prev_mood = state.mood

    state =
      state
      |> dec(:energy, 3)
      |> dec(:attention, attention_decay(state))
      |> update_mood()
      |> inc_tick_count

    # Heartbeat every 10 ticks
    if rem(state.tick_count, 10) == 0 do
      Logger.info(
        "desk_buddy heartbeat | tick=#{state.tick_count} mood=#{state.mood} " <>
          "energy=#{state.energy} attention=#{state.attention} personality=#{state.personality}"
      )
    end

    if state.mood != prev_mood do
      DeskBuddy.Display.fill(color_for(state.mood))
      log_status(state, "tick")
    end

    schedule_tick()
    {:noreply, state}
  end

  ## Helpers

  defp inc_tick_count(state),
    do: %{state | tick_count: state.tick_count + 1}

  defp schedule_tick,
    do: Process.send_after(self(), :tick, @tick_ms)

  defp update_mood(state) do
    cond do
      state.energy < 5 ->
        %{state | mood: :sleepy}

      state.attention < 20 ->
        %{state | mood: :bored}

      true ->
        %{state | mood: baseline_mood(state)}
    end
  end

  defp baseline_mood(%{personality: :grumpy}), do: :grumpy
  defp baseline_mood(_), do: :happy

  defp attention_decay(%{personality: :needy}), do: 6
  defp attention_decay(%{personality: :grumpy}), do: 4
  # chill
  defp attention_decay(_), do: 3

  defp inc(state, key, v),
    do: Map.update!(state, key, &min(&1 + v, 100))

  defp dec(state, key, v),
    do: Map.update!(state, key, &max(&1 - v, 0))

  defp touch(state),
    do: %{state | last_interaction: now()}

  defp now, do: System.system_time(:second)

  # Mood -> background color (RGB)
  # green
  defp color_for(:happy), do: {80, 200, 120}
  # yellow
  defp color_for(:bored), do: {240, 200, 80}
  # blue
  defp color_for(:sleepy), do: {100, 140, 240}
  # red
  defp color_for(:grumpy), do: {220, 80, 80}

  # Mood -> human-friendly color name
  defp color_name(:happy), do: "green"
  defp color_name(:bored), do: "yellow"
  defp color_name(:sleepy), do: "blue"
  defp color_name(:grumpy), do: "red"

  defp log_status(state, reason) do
    cname = color_name(state.mood)

    Logger.info(
      "desk_buddy #{reason} | mood=#{state.mood} | color=#{cname} | energy=#{state.energy} | " <>
        "attention=#{state.attention} | personality=#{state.personality}"
    )
  end
end
