# Overlay 1.0.0 Essentials

## Purpose

OpenAPI Overlay lets you apply repeatable changes to OpenAPI descriptions without editing the original source file.

## Required Root Fields

- `overlay`: must be `1.0.0` for this spec version.
- `info.title`: human-readable purpose.
- `info.version`: overlay document version identifier.
- `actions`: ordered list with at least one action.

Optional:
- `extends`: URI/relative URI of intended target document.
- `x-*` specification extensions.

## Action Object Rules

- `target` (required): JSONPath expression.
- `update` (optional): payload for merge/append.
- `remove` (optional): boolean, default false.
- `description` (optional): markdown-capable text.
- `x-*` extensions allowed.

Execution rules:
- Actions apply in order.
- Each action runs on the result produced by prior actions.
- `remove: true` overrides `update` in the same action.

## Update and Remove Semantics

- If `target` selects an object: `update` is recursively merged into that object.
- If `target` selects an array: `update` is appended as one new array entry.
- `target` may return zero results (no-op).
- `target` must not resolve to primitives or `null`.

Primitive updates:
- Do not target a primitive directly for replacement.
- Target the containing object and set the primitive as a field in `update`.

Array caveats:
- Avoid index-based removals where possible because indices shift.
- Primitive-valued array items are not individually replaceable/removable; update whole container structure.

## Format and Interop Notes

- Overlay documents can be JSON or YAML.
- Field names are case-sensitive.
- YAML 1.2 constraints are recommended for JSON round-tripping.

## Forward-Looking Context

There has been discussion about introducing explicit `add`/`replace` operations in future revisions, but Overlay `1.0.0` currently supports `update` and `remove` only.
