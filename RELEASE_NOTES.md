# 5.0.0

Planned major release. The package uses Git tags for SwiftPM versions; this change
prepares the release without creating a tag or publishing a GitHub release.

## Client products and authentication

- Add `SwiftOpenaiApiURLSession` and `SwiftOpenaiApiAsyncHTTPClient`, with
  `Client.urlSession(...)` and `Client.asyncHTTPClient(...)` factories returning
  the same `SwiftOpenaiApi.Client`.
- Keep the core client independent of transport implementations. Applications
  using a convenience factory must add and import the corresponding transport
  product explicitly; core no longer depends on or imports OpenAPIAsyncHTTPClient.
- Add shared authentication in `SwiftOpenaiApi`, selected from each operation's
  final OpenAPI security requirements. Use named `ApiKeyAuth` credentials for
  regular operations and `AdminApiKeyAuth` for administration operations. Both
  are bearer schemes, so the single-scheme `.bearer(...)` shorthand cannot choose
  between them. Missing credentials fail before a request is sent.
- Retain `SwiftOpenaiApiTypes.AuthenticationMiddleware(apiKey:)` as a deprecated
  compatibility API. New code uses factory authentication or
  `SwiftOpenaiApi.AuthenticationMiddleware(authentication:)`. Qualify the module
  when referring to either middleware type while importing both modules.
- Raise the minimum generator version to 1.13.0, runtime version to 1.12.0, and
  AsyncHTTPClient transport version to 1.5.0; add the URLSession transport package.
  Platform minimums and the Swift tools version are unchanged.

The HTTP types and generated client sources are unchanged. The separate
`SwiftOpenaiApiRealtimeTypes` product, realtime generation configuration, custom
fixtures, and resources are preserved. The package now offers five products.

## Verification

Both transport factories are covered offline for response decoding, default
configuration, explicit configuration overrides, and missing credentials. Shared
authentication tests cover named regular/admin credentials and dynamic providers.
All 53 tests across eight suites passed, including existing HTTP and realtime
fixtures. Regeneration preserved all 162 checked package files byte for byte.
No live API requests were made.

## Publishing after merge

From a clean, up-to-date checkout of the default branch, use the existing release
script when publication is intended:

```bash
./scripts/release_swift_package.sh --version 5.0.0
```

The script creates and pushes the annotated `5.0.0` tag and publishes a GitHub
release. It has not been run as part of this pull request.
