import json, os, sys, time, urllib.request, concurrent.futures as cf
sys.path.insert(0, os.path.dirname(__file__))
import vid
jobs = json.load(open(sys.argv[1]))
with cf.ThreadPoolExecutor(len(jobs)) as ex:
    futs = {ex.submit(lambda j: vid.run(**j), j): j["name"] for j in jobs}
    for f in cf.as_completed(futs):
        print(*f.result(), flush=True)
