import json, subprocess, sys, time

OUT = "/tmp/flare-gen/rec"
events = []
t0 = 0.0

def osa(script):
    subprocess.run(["osascript", "-e", script], check=True)

def mark(keys):
    events.append({"t": round(time.time() - t0, 2), "keys": keys})

def hotkey(key_code, mods, label):
    mark(label)
    osa(f'tell application "System Events" to key code {key_code} using {{{", ".join(m + " down" for m in mods)}}}')

def key(key_code, label):
    mark(label)
    osa(f'tell application "System Events" to key code {key_code}')

def type_text(text, cps=14):
    safe = text.replace("\\", "\\\\").replace('"', '\\"')
    osa(f'''tell application "System Events"
repeat with c in characters of "{safe}"
keystroke c
delay {1 / cps:.3f}
end repeat
end tell''')

def open_panel():
    hotkey(49, ["command", "shift"], ["⌘", "⇧", "Space"])

def new_chat():
    hotkey(45, ["command"], ["⌘", "N"])

def enter():
    key(36, ["↩"])

def escape():
    key(53, ["esc"])

def wait(s):
    time.sleep(s)

SCENES = {
    "websearch": (32, lambda: [wait(1.5), open_panel(), wait(0.8), new_chat(), wait(0.6), type_text("What's 250 USD in CAD right now?"), wait(0.4), enter()]),
    "risotto": (40, lambda: [wait(1.5), open_panel(), wait(0.8), new_chat(), wait(0.6), type_text("Walk me through a proper mushroom risotto."), wait(0.4), enter()]),
    "image": (75, lambda: [wait(1.5), open_panel(), wait(0.8), new_chat(), wait(0.6), type_text("Draw a tiny isometric desk with a laptop and a plant, soft pastel colours"), wait(0.4), enter()]),
    "queue": (45, lambda: [wait(1.5), open_panel(), wait(0.8), new_chat(), wait(0.6), type_text("How does a VPN work? Three short bullets."), wait(0.3), enter(), wait(1.2), type_text("Now compare WireGuard and OpenVPN in a table", 16), wait(0.3), enter()]),
    "search": (16, lambda: [wait(1.5), open_panel(), wait(1.0), hotkey(40, ["command"], ["⌘", "K"]), wait(0.8), type_text("trip", 7), wait(2.2), key(125, ["↓"]), wait(0.7), key(125, ["↓"]), wait(0.9), enter()]),
    "summon": (12, lambda: [wait(1.2), open_panel(), wait(2.8), escape(), wait(1.6), open_panel(), wait(2.6), escape()]),
}

if __name__ == "__main__":
    name = sys.argv[1]
    duration, script = SCENES[name]
    subprocess.run(["cliclick", "m:40,600"]); subprocess.run(["osascript", "-e", "tell application \"System Events\" to key code 53"]); time.sleep(0.6)
    rec = subprocess.Popen(["screencapture", "-x", "-v", f"-V{duration}", f"{OUT}/{name}.mov"])
    t0 = time.time()
    script()
    rec.wait()
    json.dump(events, open(f"{OUT}/{name}.json", "w"))
    print(name, events)
