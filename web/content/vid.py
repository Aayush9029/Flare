import base64, json, os, sys, time, urllib.request, subprocess, concurrent.futures as cf

KEY = os.environ["OPENROUTER_API_KEY"]
OUT = "/tmp/flare-gen/vid"
H = {"Authorization": f"Bearer {KEY}", "Content-Type": "application/json"}

def data_url(path):
    if path.endswith((".mp4", ".mov")):
        return "data:video/mp4;base64," + base64.b64encode(open(path, "rb").read()).decode()
    jpg = f"/tmp/flare-gen/.cache-{os.path.basename(path)}.jpg"
    if not os.path.exists(jpg):
        subprocess.run(["sips", "-s", "format", "jpeg", "-s", "formatOptions", "88", "-Z", "1600", path, "--out", jpg], capture_output=True)
    return "data:image/jpeg;base64," + base64.b64encode(open(jpg, "rb").read()).decode()

def call(url, payload=None):
    req = urllib.request.Request(url, json.dumps(payload).encode() if payload else None, H)
    with urllib.request.urlopen(req, timeout=300) as r:
        return json.load(r)

def run(name, prompt, first=None, last=None, refs=(), video_refs=(), duration=8, resolution="720p", aspect_ratio="16:9", audio=False, seed=None):
    path = f"{OUT}/{name}.mp4"
    if os.path.exists(path):
        return name, "exists"
    payload = dict(model="bytedance/seedance-2.5", prompt=prompt, duration=duration, resolution=resolution, aspect_ratio=aspect_ratio, generate_audio=audio)
    frames = []
    if first: frames.append({"type": "image_url", "image_url": {"url": data_url(first)}, "frame_type": "first_frame"})
    if last: frames.append({"type": "image_url", "image_url": {"url": data_url(last)}, "frame_type": "last_frame"})
    if frames: payload["frame_images"] = frames
    ir = [{"type": "image_url", "image_url": {"url": data_url(r)}} for r in refs]
    ir += [{"type": "video_url", "video_url": {"url": v if v.startswith("https://") else data_url(v)}} for v in video_refs]
    if ir: payload["input_references"] = ir
    if seed is not None: payload["seed"] = seed
    try:
        job = call("https://openrouter.ai/api/v1/videos", payload)
    except urllib.error.HTTPError as e:
        return name, "ERR submit " + e.read().decode()[:500]
    print(name, "submitted", job.get("id"), flush=True)
    while True:
        time.sleep(15)
        try:
            st = call(job["polling_url"])
        except Exception as e:
            print(name, "poll error", e, flush=True); continue
        if st["status"] == "completed":
            url = (st.get("unsigned_urls") or [f"https://openrouter.ai/api/v1/videos/{job['id']}/content?index=0"])[0]
            req = urllib.request.Request(url, headers={"Authorization": f"Bearer {KEY}"})
            open(path, "wb").write(urllib.request.urlopen(req, timeout=300).read())
            return name, f"ok cost={st.get('usage', {}).get('cost')}"
        if st["status"] in ("failed", "cancelled", "expired"):
            return name, "FAILED " + json.dumps(st.get("error"))[:500]

if __name__ == "__main__":
    jobs = json.load(open(sys.argv[1]))
    with cf.ThreadPoolExecutor(8) as ex:
        for name, status in ex.map(lambda j: run(**j), jobs):
            print(name, status, flush=True)
