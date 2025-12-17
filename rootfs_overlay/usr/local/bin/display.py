import json, sys, time
from PIL import Image, ImageDraw
from st7789 import ST7789

disp = ST7789(port=0, cs=1, dc=9, backlight=13,
              width=240, height=240, rotation=0)
disp.begin()

FACES = {
    "happy": ("^ ^", "‿", (80, 200, 120)),
    "bored": ("- -", "_", (240, 200, 80)),
    "sleepy": ("=_=", "o", (100, 140, 240)),
    "grumpy": ("> <", "︵", (220, 80, 80)),
}

def draw_face(mood):
    eyes, mouth, bg = FACES[mood]
    img = Image.new("RGB", (240,240), bg)
    d = ImageDraw.Draw(img)

    d.text((70, 80), eyes, fill="black")
    d.text((110, 130), mouth, fill="black")

    return img

while True:
    raw = sys.stdin.buffer.read(4)
    if not raw:
        continue

    size = int.from_bytes(raw, "big")
    data = sys.stdin.buffer.read(size)
    state = json.loads(data)

    img = draw_face(state["mood"])
    disp.display(img)
