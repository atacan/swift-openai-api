# Responses captures

These bodies were captured with curl from `POST https://api.openai.com/v1/responses`.
JSON and SSE bodies are saved unchanged. `Requests/` records request bodies,
`cases.json` records expected HTTP statuses, media types, and SSE terminal events,
and `captures.json` records actual statuses, media types, and UTC capture times.
See the official [Responses reference](https://developers.openai.com/api/reference/resources/responses/methods/create)
and [streaming guide](https://developers.openai.com/api/docs/guides/streaming-responses).

| Scenario | HTTP status | Coverage |
| --- | --- | --- |
| text | 200 | Assistant message, null generation error, extra billing and tool usage fields |
| tool-call | 200 | Function tool configuration, forced choice, function call output |
| tool-result | 200 | Untagged user message, previous function call, function result, assistant reply |
| structured-output | 200 | Strict JSON schema configuration and typed JSON text |
| reasoning | 200 | Reasoning item, encrypted content, reasoning token usage |
| incomplete | 200 | Output limit reached, incomplete details and message status |
| logprobs | 200 | Output text token probabilities |
| stream | 200 | Named SSE events, text deltas, final response and usage |
| tool-call-stream | 200 | Function argument deltas and final function call |
| incomplete-stream | 200 | Text deltas and `response.incomplete` termination |
| reasoning-stream | 200 | Reasoning output item and text deltas |
| missing-model | 400 | Missing required parameter |
| invalid-max-output-tokens | 400 | Invalid token limit |
| unknown-model | 404 | String code and null parameter |
| unauthenticated | 401 | Null code and parameter; no credential sent |

Text and reasoning captures use `gpt-5.6-luna`. Other successful scenarios use
`gpt-4.1-mini`. Requests explicitly set `store: false` and small output limits.
The function-result request carries a self-contained copy of a previous call
and a locally supplied result. It can be replayed without fetching a stored
response or executing a tool, even after `tool-call.json` is refreshed.

## Schema corrections

The source spec requires a non-null `Response.error` object, but successful and
in-progress responses contain `error: null`. The overlay makes only that
required property optional; the other required response and message fields
remain required and have regression tests.

Responses output, content, tool, and stream discriminators omit mappings from
wire values to component names. The overlay supplies these mappings. Input
items differ: messages can omit `type`, and input and output messages share the
same `message` tag. Their discriminator cannot select a unique schema. The
overlay removes those two discriminators so the generator uses ordinary
`oneOf` decoding. The function-result capture tests both untagged messages and
function-call input items through request decoding and serialization.

The source `ResponseStreamEvent` uses `anyOf` with a discriminator. Swift OpenAPI
Generator ignores that discriminator and generates a struct with an optional
property for every event type. The Python bootstrapper now converts a tagged
`anyOf` to `oneOf` only when every referenced branch is an object, requires the
tag, and has disjoint tag values. This preserves the accepted payloads and
produces a typed Swift enum. Unproven or overlapping unions are left unchanged, with Python
regression tests for these boundaries.

The reasoning stream has different opaque `encrypted_content` strings in its
`response.output_item.done` and `response.completed` events. Tests require both
strings to decode and compare the visible reasoning fields and item IDs, rather
than requiring ciphertext equality.

No custom Swift decoder or manual generated-source patch is used. Unknown fields
are accepted; unknown output item types and missing required core fields still
fail decoding. Null/omitted error, non-null generation error, additional-field,
and missing-field variants are created only in test memory. They are not live
API fixtures.

## Capture and test

```bash
export OPENAI_API_KEY=...  # Or load your existing credential environment.
python3 scripts/capture-api-fixtures.py responses
# Refresh only selected scenarios:
python3 scripts/capture-api-fixtures.py responses --case reasoning --case stream
swift test
```

Capture uses real, billable curl requests without retries. Authentication is
passed over stdin and headers are not saved. A mismatched status, media type,
or missing terminal event preserves the previous fixture. Responses SSE ends
with its named terminal response event, rather than the Chat `[DONE]` marker.

This set covers response creation. Retrieval, deletion, input-item listing,
background cancellation, built-in tools, and audio are not exercised here.
Only 400, 401, and 404 HTTP errors were captured; other HTTP failures and live
`response.failed` events are not covered by these captures.
