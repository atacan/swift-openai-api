# JSONPath Multi-Targeting Recipes for Overlays

## When to Read This

Use this file when an overlay action must target many objects at once, or when selector behavior is unclear.

## Core Rule

In overlays, JSONPath targets should resolve to objects/arrays you can merge into or remove from. If you need to change a primitive, target its parent object.

## Common Selector Patterns

```yaml
# Root object
target: $

# All path items
target: $.paths.*

# One concrete path item (keys with "/" should use bracket notation)
target: "$.paths['/pets']"

# A concrete operation
target: "$.paths['/pets'].get"

# All GET operations
target: $.paths.*.get

# Union of common HTTP methods under every path item
target: "$.paths.*['get','post','put','patch','delete']"

# All parameters arrays for GET operations
target: $.paths.*.get.parameters
```

## Filter Recipes (Target Multiple Objects Conditionally)

```yaml
# Query params named "filter"
target: "$.paths.*.get.parameters[?@.name=='filter' && @.in=='query']"

# Apply a paging overlay to operations tagged with a trait
target: "$.paths.*.get[?@.x-oai-traits.paged]"

# All operations carrying a custom trait/flag
target: "$.paths.*['get','post','put','patch','delete'][?@.x-oai-traits]"

# Remove operations marked internal
target: "$.paths.*[?@.x-internal==true]"

# Remove servers by description value
target: "$.servers[?@.description=='Development' || @.description=='Staging']"
```

## Safe Targeting by Update Type

- Update primitive value: target the containing object, then set the primitive in `update`.
- Update object: target the object itself.
- Append to array: target the array and provide one item in `update`.
- Remove array item: prefer predicate-based selection over numeric indices.

## Anti-Patterns

- Wildcards inside quoted keys are literal text, not glob patterns.
- Avoid: `$.paths['/internal/*']`
- Prefer explicit keys, predicates, or metadata flags like `x-internal`.

- Do not rely on primitive node targets for updates.
- Avoid:
```yaml
- target: $.info.title
  update: New Title
```
- Prefer:
```yaml
- target: $.info
  update:
    title: New Title
```

## Compatibility Caveat

JSONPath implementations differ across tooling. The overlay spec aligns to RFC 9535, but some tools historically used other dialects. For advanced expressions, validate using the exact overlay engine you will run in CI/CD.
