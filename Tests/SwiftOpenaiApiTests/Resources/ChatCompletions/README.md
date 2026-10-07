# Chat Completions captures

These response bodies were captured from `POST https://api.openai.com/v1/chat/completions`
with curl. JSON bodies and the SSE stream are saved unchanged. `Requests/` records
each request body; `cases.json` records the expected HTTP status and media type;
`captures.json` records actual statuses, content types, and UTC capture times.
The earlier `responseChatCompletion.json` is retained as a regression fixture.

| Scenario | Status | Coverage |
| --- | --- | --- |
| text | 200 | `logprobs` absent; nullable refusal and system fingerprint |
| tool-call | 200 | Null message content; `type: function` discriminator |
| logprobs | 200 | Token probabilities and nullable logprobs refusal |
| stream | 200 | Deltas, nullable finish reason and usage, final usage, `[DONE]` |
| missing-messages | 400 | String error code and parameter |
| unsupported-reasoning | 400 | Null error code and string parameter |
| unknown-model | 404 | String error code and null parameter |
| unauthenticated | 401 | Null error code and parameter; no credential sent |

The Luna captures use `gpt-5.6-luna`, matching the original failing test. The
logprobs capture uses `gpt-4.1-mini`. Function tools on `gpt-5.6-luna` require
`reasoning_effort: none`; the unsupported-reasoning fixture records the error
when that setting is omitted. Request bodies default to `store: false` and small
output limits for successful requests.

The original specification already allows null for message content, choice
logprobs, nested refusal logprobs, and error code/parameter. The bootstrapper used
to discard `anyOf`/`oneOf` null branches before its nullable-property pass could
remove those properties from `required`. That ordering is fixed in the Python
bootstrapper, with full-pipeline regression tests. The Swift generator then
produces optional properties using its existing support.

Regeneration uses Speakeasy's OpenAPI CLI to apply the overlay. The previous
formatter corrupted the negative Int64 `seed` bound into a string ending in
`===`; older formatter output rounded it instead. The bootstrapper now uses the
dedicated overlay engine, with integration tests preserving exact bounds in
both YAML and JSON output.

The spec's message-role and tool-call discriminators omit the mappings between
wire values and component names. The overlay supplies explicit mappings so that
the generated decoder accepts `user`, `function`, and the other documented values.
No custom Swift decoder or generated-source patch is needed.

Capture fixtures separately from testing:

```bash
export OPENAI_API_KEY=...  # Or load your existing credential environment.
python3 scripts/capture-chat-completions.py
swift test
```

`--case NAME` may be repeated to refresh selected scenarios. Capture requests use
curl without retries. The script requires the expected HTTP status and media
type before saving, passes authentication over stdin, and does not save headers.
Only 400, 401, and 404 errors were captured; other status codes in the overlay
have no live fixture coverage yet. Responses and audio endpoints are outside
this fixture set.
