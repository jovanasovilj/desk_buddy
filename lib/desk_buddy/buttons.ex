defmodule DeskBuddy.Buttons do
  use GenServer
  require Logger
  alias Circuits.GPIO

  @k1_pin 21
  @k2_pin 20
  @k3_pin 16

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil)
  end

  def init(_) do
    {:ok, k1} = GPIO.open(@k1_pin, :input)
    {:ok, k2} = GPIO.open(@k2_pin, :input)
    {:ok, k3} = GPIO.open(@k3_pin, :input)

    GPIO.set_pull_mode(k1, :pullup)
    GPIO.set_pull_mode(k2, :pullup)
    GPIO.set_pull_mode(k3, :pullup)

    GPIO.set_interrupts(k1, :falling)
    GPIO.set_interrupts(k2, :falling)
    GPIO.set_interrupts(k3, :falling)

    {:ok, %{k1: k1, k2: k2, k3: k3}}
  end

  def handle_info({:circuits_gpio, @k1_pin, _, 0}, s) do
    Logger.info("Button 1 pressed - Interact")
    DeskBuddy.State.interact()
    {:noreply, s}
  end

  def handle_info({:circuits_gpio, @k2_pin, _, 0}, s) do
    Logger.info("Button 2 pressed - Rest")
    DeskBuddy.State.rest()
    {:noreply, s}
  end

  def handle_info({:circuits_gpio, @k3_pin, _, 0}, s) do
    Logger.info("Button 3 pressed - Interact")
    DeskBuddy.State.interact()
    {:noreply, s}
  end
end
