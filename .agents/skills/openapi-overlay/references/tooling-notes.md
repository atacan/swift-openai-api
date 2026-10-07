# OpenAPI Overlay Tooling Notes

## When to Read This

Use this file when deciding how to apply, validate, or experiment with overlays.

## Ecosystem Snapshot

- Overlay Specification 1.0.0 is stable and published.
- Tool support exists but maturity and JSONPath behavior vary by implementation.

## Practical Tooling

### Bump CLI

Applies overlays and can be integrated into docs deployment flows.

```bash
npm install -g bump-cli
bump overlay openapi.yaml overlays.yaml > openapi.public.yaml
```

### Speakeasy CLI

Supports apply, compare, and validate flows.

```bash
# apply
speakeasy overlay apply -s openapi.yaml -o overlays.yaml > openapi.public.yaml

# validate
speakeasy overlay validate -o overlays.yaml

# compare (spec -> overlay diff)
speakeasy overlay compare -s before.yaml -t after.yaml
```

### Overlay Playground

Good for rapid experiments and inspecting the effect of selectors:
- https://overlay.speakeasy.com/

## Tooling Strategy

1. Draft overlay with conservative selectors.
2. Validate syntax/structure with your target CLI.
3. Apply to a representative spec and inspect output diff.
4. Expand selectors (wildcards/filters/unions) only after confirming engine behavior.

## JSONPath Implementation Risk

- Not all tools historically implemented the same JSONPath dialect.
- For high-impact overlays, avoid "clever" one-liners until validated in your actual runtime.
- Prefer explicit, readable selectors when portability matters.
