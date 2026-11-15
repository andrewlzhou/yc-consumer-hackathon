// @vitest-environment node
import { generateKeyPairSync, verify } from "node:crypto";
import http2 from "node:http2";
import { afterEach, expect, test } from "vitest";
import { apnsConfigFromEnv, sendRaw, signProviderToken } from "./apnsClient";

const pair = generateKeyPairSync("ec", { namedCurve: "P-256" });
const pem = pair.privateKey.export({ type: "pkcs8", format: "pem" }).toString();

test("provider token is a valid ES256 JWT with kid and team", () => {
  const jwt = signProviderToken({ keyId: "KEY1234567", teamId: "TEAM123456", privateKey: pem }, 1_700_000_000);
  const [h, p, s] = jwt.split(".");
  expect(JSON.parse(Buffer.from(h, "base64url").toString())).toEqual({ alg: "ES256", kid: "KEY1234567" });
  expect(JSON.parse(Buffer.from(p, "base64url").toString())).toEqual({ iss: "TEAM123456", iat: 1_700_000_000 });
  const ok = verify("sha256", Buffer.from(h + "." + p), { key: pair.publicKey, dsaEncoding: "ieee-p1363" }, Buffer.from(s, "base64url"));
  expect(ok).toBe(true);
});

test("config needs all four settings and accepts escaped newlines", () => {
  expect(apnsConfigFromEnv({ APNS_KEY_ID: "a" })).toBeUndefined();
  const cfg = apnsConfigFromEnv({ APNS_KEY_ID: "k", APNS_TEAM_ID: "t", APNS_BUNDLE_ID: "b", APNS_PRIVATE_KEY: "line1\\nline2" });
  expect(cfg?.privateKey).toBe("line1\nline2");
});

let server: http2.Http2Server | undefined;
afterEach(() => new Promise<void>((r) => (server ? server.close(() => r()) : r())));

test("push request carries APNs headers and payload over HTTP/2", async () => {
  const seen: { headers?: http2.IncomingHttpHeaders; body: string } = { body: "" };
  server = http2.createServer((req, res) => {
    seen.headers = req.headers;
    req.on("data", (c) => (seen.body += c));
    req.on("end", () => {
      res.writeHead(400, { "apns-id": "abc" });
      res.end(JSON.stringify({ reason: "BadDeviceToken" }));
    });
  });
  await new Promise<void>((r) => server!.listen(0, r));
  const port = (server.address() as { port: number }).port;
  const res = await sendRaw({
    host: "http://127.0.0.1:" + port,
    deviceToken: "ab".repeat(32),
    jwt: "jwt",
    topic: "com.example.app",
    message: { title: "T", body: "B", data: { productId: "p1" } },
  });
  expect(res).toEqual({ ok: false, status: 400, reason: "BadDeviceToken", apnsId: "abc" });
  expect(seen.headers).toMatchObject({ ":path": "/3/device/" + "ab".repeat(32), authorization: "bearer jwt", "apns-topic": "com.example.app", "apns-push-type": "alert" });
  expect(JSON.parse(seen.body)).toEqual({ aps: { alert: { title: "T", body: "B" }, sound: "default" }, productId: "p1" });
});
