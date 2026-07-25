---
name: openapi-overlay
description: Create, review, and apply OpenAPI Overlay 1.0.0 documents for repeatable OpenAPI changes without editing source files. Use for bulk updates/removals, metadata overlays, partner-specific variants, and JSONPath-targeted transforms.
---

# OpenAPI Overlay

Use this skill when changes should be layered on top of an OpenAPI file instead of editing the source directly.

## Quick Workflow

1. Identify input files: base OpenAPI document (`openapi.yaml`) and overlay (`overlay.yaml`) or a request to create one.
2. Start from a valid overlay skeleton:

```yaml
overlay: 1.0.0
info:
  title: Describe overlay intent
  version: 0.0.1
# extends: ./openapi.yaml  # optional but recommended when overlay is spec-specific
actions:
  - target: <JSONPath expression>
    update: <object to merge or item to append>
#   - target: <JSONPath expression>
#     remove: true
```
3. Build `actions` from broad-to-narrow: start with low-risk bulk actions (for example `$.paths.*.get`), then add narrow filters for exceptions/removals, and keep order intentional.
4. Apply overlay with the target toolchain and verify output.

## Non-Negotiable Rules (Overlay 1.0.0)

- `overlay`, `info.title`, `info.version`, and `actions` are required.
- `target` MUST resolve to zero or more objects/arrays, never primitives or `null`.
- `remove: true` takes precedence over `update`.
- If target is an object: `update` does a recursive merge.
- If target is an array: `update` appends one entry.
- Primitive array items cannot be replaced or removed individually; operate on the containing object/array.

## JSONPath Multi-Target Cheatsheet

Use these for one-action-many-objects updates:

```yaml
# All GET operations
- target: $.paths.*.get
  update:
    x-safe: true

# All common HTTP methods under every path
- target: "$.paths.*['get','post','put','patch','delete']"
  update:
    x-audience: partner

# Query parameter objects named "filter" across all GET operations
- target: "$.paths.*.get.parameters[?@.name=='filter' && @.in=='query']"
  update:
    schema:
      $ref: "#/components/schemas/FilterSchema"

# Remove operations flagged as internal
- target: "$.paths.*[?@.x-internal==true]"
  remove: true
```

Important targeting rule:
- To update primitive properties, select the containing object and set the primitive inside `update`.

## Tool Compatibility Guardrail

Overlay spec targets RFC 9535 JSONPath semantics, but tooling implementations can differ. For complex predicates or unions, validate expressions with the exact engine used by your CLI/platform before finalizing overlays.

## Progressive Disclosure

Read additional material only when needed:

- Deep spec behavior and normative constraints: `references/spec-essentials.md`
- Multi-object JSONPath recipes and anti-patterns: `references/jsonpath-multi-targeting.md`
- Tooling notes (`bump-cli`, `speakeasy`, playground): `references/tooling-notes.md`
