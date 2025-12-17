defmodule DeskBuddy.Buttons do
  use GenServer
  alias Circuits.GPIO

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil)
  end

  def init(_) do
    {:ok, a} = GPIO.open(17, :input)
    {:ok, b} = GPIO.open(27, :input)

    GPIO.set_interrupts(a, :both)
    GPIO.set_interrupts(b, :both)

    {:ok, %{a: a, b: b}}
  end

  def handle_info({:circuits_gpio, 17, _, 0}, state) do
    DeskBuddy.State.interact()
    {:noreply, state}
  end

  def handle_info({:circuits_gpio, 27, _, 0}, state) do
    DeskBuddy.State.rest()
    {:noreply, state}
  end
end
