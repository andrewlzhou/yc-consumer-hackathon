// Thin wrapper around the OpenAI Responses API (plain fetch, no SDK needed).
// Env vars: OPENAI_API_KEY (required), OPENAI_MODEL (deep pass), OPENAI_FAST_MODEL (quick pass).

export async function callOpenAI(opts: {
  input: unknown;
  tools?: unknown[];
  fast?: boolean;
}): Promise<string> {
  const model = opts.fast
    ? process.env.OPENAI_FAST_MODEL ?? process.env.OPENAI_MODEL
    : process.env.OPENAI_MODEL;
  if (!model) throw new Error("Set OPENAI_MODEL (and ideally OPENAI_FAST_MODEL) in Convex env");
  const res = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${process.env.OPENAI_API_KEY}`,
    },
    body: JSON.stringify({ model, input: opts.input, tools: opts.tools }),
  });
  if (!res.ok) throw new Error(`OpenAI ${res.status}: ${(await res.text()).slice(0, 500)}`);
  const data: any = await res.json();
  if (typeof data.output_text === "string" && data.output_text) return data.output_text;
  const texts: string[] = [];
  for (const item of data.output ?? []) {
    if (item.type !== "message") continue;
    for (const c of item.content ?? []) if (c.type === "output_text" && c.text) texts.push(c.text);
  }
  return texts.join("\n");
}

// Models sometimes wrap JSON in prose or code fences. Grab the outermost object.
export function parseJSON<T>(text: string): T {
  const start = text.indexOf("{");
  const end = text.lastIndexOf("}");
  if (start === -1 || end <= start) throw new Error(`No JSON in model output: ${text.slice(0, 200)}`);
  return JSON.parse(text.slice(start, end + 1)) as T;
}

// If your account rejects "web_search", try { type: "web_search_preview" }.
export const WEB_SEARCH = [{ type: "web_search" }];
