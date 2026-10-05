import base64, json, os, sys, urllib.request, concurrent.futures as cf

PROMPTS = {
 "m-piano": "30 second instrumental score for an elegant Apple-style product film set at sunset by the ocean. 0-5s: warm felt piano and soft ambient pad, spacious. 5s: a gentle, satisfying downbeat hit with a soft kick and a warm sub-bass swell, as if a key is pressed. 5-20s: light brushed percussion and a plucked guitar ostinato join, hopeful and flowing, the piano melody rising. 20-26s: strings swell to a warm, uplifting peak. 26-30s: everything resolves to one sustained piano chord and fades. Cinematic, tasteful, modern, no vocals, no drops.",
 "m-guitar": "30 second instrumental for a cinematic lifestyle film of a creator working outdoors at golden hour. Warm fingerpicked acoustic guitar, soft handclaps and airy synth pads, gentle and optimistic, in the spirit of an Apple commercial. A soft percussive accent at 5 seconds, a fuller groove with light drums from 6 to 24 seconds, a warm lift at 20 seconds, and a clean ending on a ringing chord at 28 seconds. No vocals.",
 "m-ambient": "30 second minimalist instrumental for a premium tech brand film: soft analog synth arpeggio, warm Rhodes chords, subtle vinyl texture and gentle ocean-like noise swells. Calm opening, a crisp muted percussive tick pattern starting at 5 seconds, slowly building warmth and brightness, a small uplifting chord change at 20 seconds, resolving softly at 28 seconds. Elegant, restrained, no vocals.",
}

def gen(name, prompt):
    body = {"model": "google/lyria-3-clip-preview", "stream": True, "modalities": ["text", "audio"], "messages": [{"role": "user", "content": prompt}]}
    req = urllib.request.Request("https://openrouter.ai/api/v1/chat/completions", json.dumps(body).encode(), {"Authorization": "Bearer " + os.environ["OPENROUTER_API_KEY"], "Content-Type": "application/json"})
    chunks = []
    with urllib.request.urlopen(req, timeout=600) as r:
        for line in r:
            line = line.decode().strip()
            if not line.startswith("data: ") or line == "data: [DONE]": continue
            for c in json.loads(line[6:]).get("choices", []):
                a = c.get("delta", {}).get("audio")
                if a and a.get("data"): chunks.append(a["data"])
    open(f"film/{name}.mp3", "wb").write(b"".join(base64.b64decode(c) for c in chunks))
    return name

with cf.ThreadPoolExecutor(3) as ex:
    for n in ex.map(lambda kv: gen(*kv), PROMPTS.items()): print(n, "ok", flush=True)
