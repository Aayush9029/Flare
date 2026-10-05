import json, subprocess

REC = "/tmp/flare-gen/rec"
OUT = "/tmp/flare-gen/web"
OFFSET = 0.45
CROP = "crop=1868:1400:1732:938"

EDITS = {
    "websearch": (0.8, 19.5, [(7.5, 14.5, 2.5)]),
    "risotto": (0.8, 20.0, [(8.0, 11.5, 2.0)]),
    "image": (0.8, 33.0, [(10.0, 27.5, 5.0)]),
    "queue": (0.8, 24.0, [(13.0, 19.0, 2.5)]),
    "search": (0.8, 12.0, []),
    "summon": (0.5, 8.7, []),
}

def segments(start, end, fast):
    segs, t = [], start
    for a, b, speed in fast:
        segs.append((t, a, 1.0)); segs.append((a, b, speed)); t = b
    segs.append((t, end, 1.0))
    return [s for s in segs if s[1] > s[0]]

def remap(t, segs):
    out = 0.0
    for a, b, speed in segs:
        if t <= a: return None if out == 0 and t < a else out
        if t < b: return out + (t - a) / speed
        out += (b - a) / speed
    return None

for name, (start, end, fast) in EDITS.items():
    segs = segments(start, end, fast)
    parts, labels = [], []
    for i, (a, b, speed) in enumerate(segs):
        parts.append(f"[0:v]trim={a}:{b},setpts=(PTS-STARTPTS)/{speed},fps=30[s{i}]")
        labels.append(f"[s{i}]")
    graph = ";".join(parts) + f";{''.join(labels)}concat=n={len(segs)}:v=1:a=0,{CROP},scale=1440:1080:flags=lanczos,format=yuv420p[v]"
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", f"{REC}/{name}.mov", "-filter_complex", graph, "-map", "[v]",
                    "-c:v", "libx264", "-preset", "slow", "-crf", "22", "-movflags", "+faststart", "-an", f"{OUT}/app-{name}.mp4"], check=True)
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-sseof", "-0.5", "-i", f"{OUT}/app-{name}.mp4", "-frames:v", "1", "-q:v", "3", f"{OUT}/app-{name}.jpg"], check=True)
    cues = []
    for e in json.load(open(f"{REC}/{name}.json")):
        t = remap(e["t"] + OFFSET, segs)
        if t is not None: cues.append({"t": round(t, 2), "keys": e["keys"]})
    json.dump(cues, open(f"{OUT}/app-{name}.cues.json", "w"), ensure_ascii=False)
    dur = sum((b - a) / s for a, b, s in segs)
    print(name, f"{dur:.1f}s", cues)
