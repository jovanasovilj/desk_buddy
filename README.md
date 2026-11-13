# Desk Buddy

A small desk pet that lives on a Raspberry Pi Zero 2 W. It is built with
[Nerves](https://nerves-project.org) and written in Elixir, including the
driver for its screen.

Desk Buddy has a mood that changes over time. Its energy and attention go down
slowly, so it needs you to play with it or let it rest. The screen shows its
mood as a colour.

**Status:** work in progress. The mood is shown as a full screen colour for
now. Faces and simple animations are next.

## Hardware

- Raspberry Pi Zero 2 W
- Waveshare 1.3 inch LCD HAT (ST7789 controller, 240x240 pixels, SPI)

## How it works

The application starts three supervised GenServers.

- `DeskBuddy.Display` talks to the ST7789 panel over SPI and GPIO. It resets
  and sets up the panel and fills the screen with RGB565 pixels, sent in
  chunks of 4 KB.
- `DeskBuddy.State` keeps the mood, energy and attention. Every 3 seconds a
  tick lowers energy and attention. When the mood changes, it updates the
  screen.
- `DeskBuddy.Buttons` listens for button presses through GPIO interrupts.

### Moods

| Mood   | Colour | When                                    |
|--------|--------|-----------------------------------------|
| happy  | green  | energy and attention are fine           |
| bored  | yellow | attention drops below 20                |
| sleepy | blue   | energy drops below 5                    |
| grumpy | red    | the normal mood of a grumpy personality |

### Buttons

| Button | GPIO | Action                         |
|--------|------|--------------------------------|
| KEY1   | 21   | play: attention +15, energy +5 |
| KEY2   | 20   | rest: energy +20, attention -5 |
| KEY3   | 16   | play, same as KEY1             |

### Personality

A buddy can be `chill`, `needy` or `grumpy`. A needy buddy gets bored faster
and a grumpy one is red when nothing is wrong. Change it from an IEx session on
the device:

```elixir
DeskBuddy.State.set_personality(:needy)
```

## Build and flash

`.nerves-env` keeps the Mix and Hex files inside the project folder.

```sh
source .nerves-env
export MIX_TARGET=rpi0_2
mix deps.get
mix firmware

# First time: write the firmware to an SD card
mix burn

# Later updates over the network
./upload.sh
```

Once it is running, `ssh nerves.local` opens an IEx prompt on the device.

## Ideas

- Faces and simple animations instead of plain colours
- Let the buddy talk: ask an LLM for a short line that fits its mood and show
  it on the screen
- Use the joystick on the HAT
- Remember the mood across reboots
