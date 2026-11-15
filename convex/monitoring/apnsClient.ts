"use node";
// Minimal APNs client: ES256 provider token (node:crypto) plus an HTTP/2 request (node:http2). No dependencies.
import { createPrivateKey, sign } from "node:crypto";
import http2 from "node:http2";

export type ApnsEnvironment = "sandbox" | "production";
export type ApnsConfig = { keyId: string; teamId: string; privateKey: string; bundleId: string };
export type ApnsResult = { ok: boolean; status: number; reason?: string; apnsId?: string };

const HOSTS: Record<ApnsEnvironment, string> = {
  sandbox: "https://api.sandbox.push.apple.com",
  production: "https://api.push.apple.com",
};

// Reads the four APNs settings. A .p8 pasted into an env var may have its newlines escaped.
export function apnsConfigFromEnv(env: Record<string, string | undefined> = process.env): ApnsConfig | undefined {
  const { APNS_KEY_ID: keyId, APNS_TEAM_ID: teamId, APNS_PRIVATE_KEY: key, APNS_BUNDLE_ID: bundleId } = env;
  if (!keyId || !teamId || !key || !bundleId) return undefined;
  return { keyId, teamId, bundleId, privateKey: key.replace(/\\n/g, "\n") };
}

const b64 = (o: object) => Buffer.from(JSON.stringify(o)).toString("base64url");

// Apple wants a fresh token at least hourly and rejects ones older than an hour.
export function signProviderToken(cfg: Pick<ApnsConfig, "keyId" | "teamId" | "privateKey">, nowSec = Math.floor(Date.now() / 1000)) {
  const head = b64({ alg: "ES256", kid: cfg.keyId });
  const claims = b64({ iss: cfg.teamId, iat: nowSec });
  const signature = sign("sha256", Buffer.from(`${head}.${claims}`), {
    key: createPrivateKey(cfg.privateKey),
    dsaEncoding: "ieee-p1363",
  }).toString("base64url");
  return `${head}.${claims}.${signature}`;
}

export type ApnsMessage = { title: string; body: string; data?: Record<string, unknown> };

// One request on a short-lived HTTP/2 connection; a few pushes per sweep do not need pooling.
export function sendRaw(args: {
  host: string;
  deviceToken: string;
  jwt: string;
  topic: string;
  message: ApnsMessage;
  collapseId?: string;
}): Promise<ApnsResult> {
  return new Promise((resolve, reject) => {
    const client = http2.connect(args.host);
    client.on("error", reject);
    const headers: Record<string, string> = {
      ":method": "POST",
      ":path": `/3/device/${args.deviceToken}`,
      authorization: `bearer ${args.jwt}`,
      "apns-topic": args.topic,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "content-type": "application/json",
    };
    if (args.collapseId) headers["apns-collapse-id"] = args.collapseId.slice(0, 64);
    const req = client.request(headers);
    let status = 0;
    let apnsId: string | undefined;
    let text = "";
    req.on("response", (h) => {
      status = Number(h[":status"]);
      apnsId = h["apns-id"] as string | undefined;
    });
    req.setEncoding("utf8");
    req.on("data", (d) => (text += d));
    req.on("error", reject);
    req.on("end", () => {
      client.close();
      const reason = text ? (JSON.parse(text) as { reason?: string }).reason : undefined;
      resolve({ ok: status === 200, status, reason, apnsId });
    });
    req.setTimeout(10_000, () => req.close(http2.constants.NGHTTP2_CANCEL));
    req.end(JSON.stringify({ aps: { alert: { title: args.message.title, body: args.message.body }, sound: "default" }, ...args.message.data }));
  });
}

export async function sendApns(cfg: ApnsConfig, env: ApnsEnvironment, deviceToken: string, message: ApnsMessage, collapseId?: string) {
  return sendRaw({ host: HOSTS[env], deviceToken, jwt: signProviderToken(cfg), topic: cfg.bundleId, message, collapseId });
}
