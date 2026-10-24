We generate the Swift code using swift-openapi-generator. As we apply complex transformations to the original OpenAPI specification, we use a Python tool to do this. Run the generation with 

```bash
make regenerate
```

As this is a Swift package, you can find the code of the Swift package dependencies in the ".build/checkouts/" directory. Look at that folder when you need to understand how to use the code from the Swift package dependencies.


The HTTP products are SwiftOpenaiApiTypes, SwiftOpenaiApi,
SwiftOpenaiApiURLSession, and SwiftOpenaiApiAsyncHTTPClient. Preserve the separate
SwiftOpenaiApiRealtimeTypes product, generation configuration, and tests.
Keep transport imports/dependencies out of core and Types. Shared authentication
belongs to core; do not edit Authentication/GeneratedSecurity/OperationSecurity.swift.
The deprecated Types authentication middleware remains for compatibility.

Both factories use the final specification's named bearer credentials:

```swift
import Foundation
import SwiftOpenaiApi
import SwiftOpenaiApiURLSession
let client = Client.urlSession(
    serverURL: URL(string: "https://api.openai.com/v1")!,
    authentication: .credentials(["ApiKeyAuth": .init("YOUR_API_KEY")])
)
```

```swift
import Foundation
import SwiftOpenaiApi
import SwiftOpenaiApiAsyncHTTPClient
let client = Client.asyncHTTPClient(
    serverURL: URL(string: "https://api.openai.com/v1")!,
    authentication: .credentials(["ApiKeyAuth": .init("YOUR_API_KEY")])
)
```

Administration operations require AdminApiKeyAuth. There are two bearer schemes,
so the single-scheme .bearer shorthand is ambiguous. Never read or print secrets.

Use offline validation explicitly:

```bash
swift build
swift test --filter 'ChatCompletionsTests|ResponsesTests|AudioTests|RealtimeTypesTests|URLSessionFactoryTests|AsyncHTTPClientFactoryTests|AuthenticationTests|SwiftOpenaiApiTypesTests'
```

These tests use fixtures or intercept requests before transport invocation.
Fixture capture scripts make billable live requests; run only when authorized.
After resolving dependency changes, regenerate HTTP and realtime sources before
building/testing. Factory edits and this file are preserved on reruns.

If response decoding reports `Expected date string to be ISO8601-formatted`,
inspect the schema and actual timestamp format. The current schemas use numeric
timestamps. If a future schema uses fractional ISO 8601 dates, set
`configuration: .init(dateTranscoder: .iso8601WithFractionalSeconds)` in both
provider factories while retaining explicit caller overrides. Test both factories
offline. Runtime configuration affects HTTP conversion; standalone JSONDecoder
instances still require their own dateDecodingStrategy. Direct Client initialization
bypasses factory defaults.
