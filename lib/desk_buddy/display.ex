defmodule DeskBuddy.Display do
  use GenServer
  require Logger
  import Bitwise

  alias Circuits.GPIO
  alias Circuits.SPI

  @w 240
  @h 240

  # Waveshare 1.3" LCD HAT pins (BCM)
  @dc 25
  @rst 27
  @bl 24

  @max_spi_chunk 4096

  # ST7789 commands
  @swreset 0x01
  @slpout 0x11
  @colmod 0x3A
  @madctl 0x36
  @invon 0x21
  @noron 0x13
  @dispon 0x29
  @caset 0x2A
  @raset 0x2B
  @ramwr 0x2C

  def start_link(_), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  # Convenience API
  def fill(rgb), do: GenServer.cast(__MODULE__, {:fill, rgb})

  @impl true
  def init(_) do
    {:ok, dc} = GPIO.open(@dc, :output)
    {:ok, rst} = GPIO.open(@rst, :output)
    {:ok, bl} = GPIO.open(@bl, :output)

    GPIO.write(bl, 1)

    {:ok, spi} = SPI.open("spidev0.0", mode: 0, speed_hz: 16_000_000, bits_per_word: 8)

    state = %{spi: spi, dc: dc, rst: rst, bl: bl}
    hw_reset(state)
    init_panel(state)

    {:ok, state}
  end

  @impl true
  def handle_cast({:fill, {r, g, b}}, state) do
    set_window_full(state)
    px = rgb565(r, g, b)
    line = :binary.copy(px, @w)

    Enum.each(1..@h, fn _ ->
      data(state, line)
    end)

    {:noreply, state}
  end

  # ----- Low-level helpers -----

  defp hw_reset(%{rst: rst}) do
    GPIO.write(rst, 1)
    Process.sleep(5)
    GPIO.write(rst, 0)
    Process.sleep(50)
    GPIO.write(rst, 1)
    Process.sleep(120)
  end

  defp init_panel(state) do
    cmd(state, @swreset)
    Process.sleep(120)

    cmd(state, @slpout)
    Process.sleep(120)

    # 16-bit color
    cmd(state, @colmod)
    data(state, <<0x55>>)
    Process.sleep(10)

    # Memory access control (rotation/origin)
    cmd(state, @madctl)
    data(state, <<0x70>>)

    # many IPS panels want inversion on
    cmd(state, @invon)
    Process.sleep(10)

    cmd(state, @noron)
    Process.sleep(10)

    cmd(state, @dispon)
    Process.sleep(120)

    set_window_full(state)
  end

  defp set_window_full(state) do
    # Column address set: 0..239
    cmd(state, @caset)
    data(state, <<0x00, 0x00, 0x00, @w - 1>>)

    # Row address set: 0..239
    cmd(state, @raset)
    data(state, <<0x00, 0x00, 0x00, @h - 1>>)

    cmd(state, @ramwr)
  end

  defp cmd(%{spi: spi, dc: dc}, byte) do
    GPIO.write(dc, 0)
    {:ok, _} = SPI.transfer(spi, <<byte>>)
  end

  defp data(state, bin) when byte_size(bin) > @max_spi_chunk do
    <<chunk::binary-size(@max_spi_chunk), rest::binary>> = bin
    data(state, chunk)
    data(state, rest)
  end

  defp data(%{spi: spi, dc: dc}, bin) do
    GPIO.write(dc, 1)
    {:ok, _} = SPI.transfer(spi, bin)
  end

  defp rgb565(r, g, b) do
    r5 = (r &&& 0xF8) >>> 3
    g6 = (g &&& 0xFC) >>> 2
    b5 = (b &&& 0xF8) >>> 3
    v = r5 <<< 11 ||| g6 <<< 5 ||| b5
    <<v::16-big>>
  end
end
