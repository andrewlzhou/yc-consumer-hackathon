# Try the backend now

- There is no iOS app yet. The live backend, verdict cards and reports can be tried from a terminal.
- You need repository access and Convex access to this project. The internal eval needs **no APP_API_KEY**.

## Fresh checkout and no-write live demo

```sh
git clone --branch ruhaan_backend https://github.com/andrewlzhou/yc-consumer-hackathon.git
cd yc-consumer-hackathon
npm ci
npx convex login
CONVEX_DEPLOYMENT=dev:scintillating-caterpillar-190 node eval/run.mjs --cases eval/run-cases-demo.json --full
```

- Skip login if this shell already has its authorized `CONVEX_DEPLOY_KEY`. It overrides deployment selection;
  make sure it belongs to this shared dev deployment. Do not run `convex dev` or `deploy` to try the demo.
- The eval uses real OpenAI calls (billed to the deployment's key), but writes no app data, queues no jobs,
  uses no SerpApi searches and skips the cache. It prints matches, verdicts, reasons, grounding and timings.
- For sample/adversarial scenarios: `node eval/run.mjs --full` with the same deployment selection.

## Optional HTTP smoke test (writes a scan)

- Copy the **existing** APP_API_KEY from the shared dev deployment's environment variables in the Convex dashboard.
  Paste it only into the hidden prompt below; never put it in a file, command history, screenshot or commit.

```bash
read -rsp 'APP_API_KEY: ' APP_API_KEY; echo
export APP_API_KEY
python3 - <<'PY'
import json, os, urllib.request, uuid
site = 'https://scintillating-caterpillar-190.convex.site'
headers = {'x-api-key': os.environ['APP_API_KEY'], 'content-type': 'application/json'}
device = 'smoke-' + str(uuid.uuid4())
def call(path, body=None):
    data = None if body is None else json.dumps(body).encode()
    with urllib.request.urlopen(urllib.request.Request(site + path, data=data, headers=headers)) as r:
        return json.load(r)
card = call('/analyze', {'deviceId': device, 'retailer': 'Best Buy',
    'title': 'Sony WH-1000XM5 Wireless Noise Canceling Headphones', 'currentPrice': 198})
print(json.dumps(card, indent=2))
if 'productId' in card:
    print(json.dumps(call('/report?productId=' + card['productId']), indent=2))
print('Watchlist:', json.dumps(call('/watchlist?deviceId=' + device)))
print('Inbox:', json.dumps(call('/watchlist/notifications?deviceId=' + device)))
PY
unset APP_API_KEY
```

- `/analyze` writes an observation, scan log and analysis; use a separate test device as above. A test device does
  not isolate the shared product history. Avoid fake prices; operators can remove their probe rows with
  `agent/store:deleteTestArtifacts` and the exact probe start time (it removes other scans after that time too).
- `/report` initially contains a chart and preliminary sections; fetch it again after roughly 10 seconds for the
  full model report. Watchlist save/target/preferences and the inbox API are in [monitoring](monitoring.md).
- Without either Convex access or the app API key there is no public demo endpoint; authentication stays closed.
