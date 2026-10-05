import base64, json, os, subprocess, sys, time, urllib.request, uuid, concurrent.futures as cf

KEY = os.environ["OPENAI_API_KEY"]
OUT = "/tmp/flare-gen/img"

def generate(name, prompt, size="1536x1024", model="gpt-image-2.5-sunburst", background=None, refs=None, quality="high"):
    path = f"{OUT}/{name}.png"
    if os.path.exists(path):
        return name, "exists"
    if refs:
        boundary = uuid.uuid4().hex
        parts = []
        def field(k, v):
            parts.append(f"--{boundary}\r\nContent-Disposition: form-data; name=\"{k}\"\r\n\r\n{v}\r\n".encode())
        for k, v in dict(model=model, prompt=prompt, size=size, quality=quality, **({"background": background} if background else {})).items():
            field(k, v)
        for r in refs:
            jpg = f"/tmp/flare-gen/.ref-{os.path.basename(r)}.jpg"
            if not os.path.exists(jpg):
                subprocess.run(["sips", "-s", "format", "jpeg", "-s", "formatOptions", "85", "-Z", "1536", r, "--out", jpg], capture_output=True)
            data = open(jpg, "rb").read()
            parts.append(f"--{boundary}\r\nContent-Disposition: form-data; name=\"image[]\"; filename=\"{os.path.basename(jpg)}\"\r\nContent-Type: image/jpeg\r\n\r\n".encode() + data + b"\r\n")
        body = b"".join(parts) + f"--{boundary}--\r\n".encode()
        req = urllib.request.Request("https://api.openai.com/v1/images/edits", body, {"Authorization": f"Bearer {KEY}", "Content-Type": f"multipart/form-data; boundary={boundary}"})
    else:
        payload = dict(model=model, prompt=prompt, size=size, quality=quality)
        if background:
            payload["background"] = background
        req = urllib.request.Request("https://api.openai.com/v1/images/generations", json.dumps(payload).encode(), {"Authorization": f"Bearer {KEY}", "Content-Type": "application/json"})
    for attempt in range(3):
        try:
            with urllib.request.urlopen(req, timeout=900) as r:
                d = json.load(r)
            break
        except urllib.error.HTTPError as e:
            return name, "ERR " + e.read().decode()[:400]
        except Exception as e:
            print(name, "retry", attempt, e, flush=True)
            time.sleep(5)
    else:
        return name, "ERR network"
    open(path, "wb").write(base64.b64decode(d["data"][0]["b64_json"]))
    return name, "ok"

if __name__ == "__main__":
    jobs = json.load(open(sys.argv[1]))
    with cf.ThreadPoolExecutor(6) as ex:
        for name, status in ex.map(lambda j: generate(**j), jobs):
            print(name, status, flush=True)
