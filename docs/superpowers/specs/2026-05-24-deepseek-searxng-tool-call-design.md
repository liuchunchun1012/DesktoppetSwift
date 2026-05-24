# DeepSeek SearXNG Tool Call Design

Date: 2026-05-24

## Goal

Add DeepSeek as a first-class AI provider and give it web search through model-driven tool calls. DeepSeek will decide when it needs current web information, the app will execute the search through SearXNG, and the final answer will cite the search result URLs.

Image analysis is out of scope for this change. DeepSeek does not currently expose a native vision API in the referenced official docs, and the user chose to skip OCR/vision for now.

## Source Constraints

- DeepSeek chat completions are OpenAI-compatible enough to reuse the existing `OpenAICompatibleClient` transport and streaming parser.
- DeepSeek supports function/tool calling, but tools are executed by the client app, not by DeepSeek itself.
- SearXNG exposes a search API with `format=json`, but public instances may disable JSON output and return `403 Forbidden`.
- Because public SearXNG instances are unreliable, the app should ship with a default public instance pool and also allow an optional user-provided SearXNG URL.

## User Experience

Settings gains a dedicated DeepSeek provider:

- Display name: `DeepSeek`
- Default API base URL: `https://api.deepseek.com`
- Recommended models: `deepseek-v4-flash`, `deepseek-v4-pro`, `deepseek-chat`, `deepseek-reasoner`
- API key stored separately under the DeepSeek provider key

Advanced AI settings continue to expose `Enable Web Search`. For DeepSeek, that toggle enables SearXNG-backed tool calls.

The app should work without Docker or local setup by trying bundled public SearXNG instances. If every public instance fails, the user can set a custom SearXNG URL. The UI should not require configuring SearXNG before DeepSeek can be used for normal chat.

When a user invokes image analysis while DeepSeek is active, the app should return a clear text error explaining that DeepSeek mode currently does not support image analysis and suggesting switching to a vision-capable provider.

## Architecture

Add `deepseek` to `AIProviderType` and route it through `OpenAICompatibleClient`.

Add a small SearXNG search client:

- Accepts a query string and result limit.
- Tries a user-configured base URL first if present.
- Falls back to a built-in list of public SearXNG instances.
- Calls `/search` with `q`, `format=json`, `language=auto`, and `safesearch=1`.
- Parses organic result objects into title, URL, and content/snippet.
- Skips failed instances and continues to the next.
- Returns a concise failure if no instance works.

Add DeepSeek-specific tool-call handling to the OpenAI-compatible chat flow:

1. Send the initial chat request with `tools` containing a `web_search` function when DeepSeek web search is enabled.
2. Stream or parse the model response until either final text or tool calls are available.
3. If DeepSeek requests `web_search`, execute SearXNG in app code.
4. Send a second chat completion with the original messages, the assistant tool call message, and the tool result message.
5. Stream the final answer to the existing chat bubble callbacks.

Tool schema:

- Name: `web_search`
- Description: Search the web for current information and return concise results with source URLs.
- Parameters:
  - `query` string, required
  - `count` integer, optional, default 5

Tool result format should be compact plain text or JSON. It must include each result's title, URL, and snippet so DeepSeek can cite sources.

## Error Handling

- If SearXNG fails while DeepSeek requested a search, return a tool result describing the failure and let DeepSeek answer from its own knowledge with a caveat.
- If the DeepSeek API returns an HTTP error, keep the existing provider error behavior.
- If tool call parsing fails, complete with a readable provider error rather than hanging the stream.
- If no search results are found, return an empty-results tool message and ask DeepSeek to say it did not find reliable web results.

## Testing

Add focused tests or manual verification around:

- DeepSeek appears in provider settings and saves its API key/config independently.
- DeepSeek normal text chat still works with web search disabled.
- With web search enabled, a mocked or known SearXNG endpoint produces a second DeepSeek request containing tool results.
- Public-instance failure falls through to the next instance or to the configured custom URL.
- DeepSeek image analysis returns the intended unsupported-capability message.

Manual build verification should include `swift build`.

## Implementation Notes

Keep the first implementation narrow:

- Do not add OCR.
- Do not add local Docker orchestration.
- Do not scrape HTML search pages as a fallback.
- Do not introduce external Swift package dependencies.
- Prefer adding small Codable structs for request/response parsing over expanding dynamic dictionary handling further.
