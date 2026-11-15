// Shared API-key check for every HTTP route. Fails closed: with no APP_API_KEY configured, requests are refused
// unless APP_ALLOW_UNAUTHENTICATED=1 is set explicitly (local development and tests only).
export function isAuthorized(req: Request): boolean {
  const key = process.env.APP_API_KEY;
  if (!key) return process.env.APP_ALLOW_UNAUTHENTICATED === "1";
  const sent = req.headers.get("x-api-key") ?? "";
  let diff = sent.length ^ key.length;
  for (let i = 0; i < key.length; i++) diff |= key.charCodeAt(i) ^ sent.charCodeAt(i % Math.max(sent.length, 1));
  return diff === 0;
}
