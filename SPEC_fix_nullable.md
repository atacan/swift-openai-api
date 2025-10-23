# OpenAPI Nullable Fix Specification

## Problem Statement

The current `openapi.yaml` file uses OpenAPI 3.0.x syntax (`nullable: true`) which generates validation warnings when parsed as OpenAPI 3.1.0. This needs to be converted to OpenAPI 3.1.0 compatible syntax.

## Objective

Create a JavaScript script that transforms all instances of `nullable: true` in the OpenAPI YAML file to OpenAPI 3.1.0 compatible syntax using JSON Schema type arrays.

## Transformation Rules

### Rule 1: Simple Type with nullable

**Before:**
```yaml
property_name:
  type: string
  nullable: true
```

**After:**
```yaml
property_name:
  type: [string, "null"]
```

### Rule 2: Type with allOf/oneOf/anyOf and nullable

**Before:**
```yaml
property_name:
  allOf:
    - $ref: '#/components/schemas/SomeSchema'
  nullable: true
```

**After:**
```yaml
property_name:
  anyOf:
    - $ref: '#/components/schemas/SomeSchema'
    - type: "null"
```

Note: `allOf` changes to `anyOf` to allow either the schema OR null.

### Rule 3: Array type with nullable

**Before:**
```yaml
property_name:
  type: array
  items:
    type: string
  nullable: true
```

**After:**
```yaml
property_name:
  type: [array, "null"]
  items:
    type: string
```

### Rule 4: Object type with nullable

**Before:**
```yaml
property_name:
  type: object
  properties:
    # ...
  nullable: true
```

**After:**
```yaml
property_name:
  type: [object, "null"]
  properties:
    # ...
```

### Rule 5: Enum or complex oneOf with nullable

**Before:**
```yaml
property_name:
  type: string
  enum:
    - value1
    - value2
  nullable: true
```

**After:**
```yaml
property_name:
  oneOf:
    - type: string
      enum:
        - value1
        - value2
    - type: "null"
```

## Implementation Requirements

### Input/Output
- **Input File:** `openapi.yaml` (2.3MB YAML file)
- **Output:** Modified `openapi.yaml` (overwrite or create backup)

### Processing Steps

1. **Parse YAML:** Load the YAML file while preserving comments and structure
2. **Traverse Schema:** Walk through all schema objects in `components.schemas` and all parameter/request/response schemas
3. **Detect Patterns:** Identify properties with `nullable: true`
4. **Apply Rules:** Apply the appropriate transformation rule based on the context
5. **Remove nullable:** Delete the `nullable: true` property after transformation
6. **Write YAML:** Output the modified YAML preserving formatting

### Edge Cases to Handle

1. **Multiple Types:** If a property already has multiple types (rare), merge with "null"
   ```yaml
   type: [string, integer]
   nullable: true
   ```
   Becomes:
   ```yaml
   type: [string, integer, "null"]
   ```

2. **Nested nullable:** Properties within properties that have nullable
3. **Both allOf and oneOf:** Choose the appropriate transformation
4. **Properties without explicit type:** Some schemas might have only $ref or allOf without a type property

### Known Locations (Examples)

The script should handle ALL occurrences throughout the file, but here are known examples:

- `CreateThreadAndRunRequest` at line ~38850
  - `model` at line 38904
  - `instructions` at line 38908
  - `tools` at line 38911
  - `tool_resources` at line 38942
  - `temperature` at line 38951
  - `top_p` at line 38960
  - `stream` at line 38967
  - `max_prompt_tokens` at line 38972
  - `max_completion_tokens` at line 38978
  - `truncation_strategy` at line 38985
  - `tool_choice` at line 38989
  - `response_format` at line 38994

## Technical Constraints

1. **YAML Library:** Use a YAML library that preserves comments and formatting (e.g., `yaml` npm package with `preserveComments` option)
2. **Backup:** Create a backup of the original file before modification
3. **Validation:** Optionally validate the output YAML is still valid
4. **Dry Run:** Support a `--dry-run` flag to preview changes without writing

## Success Criteria

1. All instances of `nullable: true` are removed
2. All properties that were nullable now accept null using OpenAPI 3.1.0 syntax
3. The YAML structure and formatting are preserved
4. No validation warnings about nullable property
5. The file remains valid OpenAPI 3.1.0 specification

## Usage Example

```bash
node fix-nullable.js openapi.yaml
# or with backup
node fix-nullable.js openapi.yaml --backup openapi.yaml.bak
# or dry run
node fix-nullable.js openapi.yaml --dry-run
```

## Testing

Create a test case with a small YAML snippet containing all transformation rule patterns and verify the output matches expected results.
