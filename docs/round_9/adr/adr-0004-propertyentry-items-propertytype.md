------
title: "ADR-0004: PropertyEntry.items should be PropertyType, not PropertyEntry"
status: "Accepted"
date: "2025-09-01"
authors: "Daniel Couturier, OpenAI ToolFlow Team"
tags: ["architecture", "decision", "PropertyEntry", "PropertyType", "array", "schema"]
supersedes: "ADR-0001: Structured OutputSchema Implementation and Code Cleanup"
superseded_by: ""
adr_references: []
used_as_resource_in: []
------

# ADR-0004: PropertyEntry.items should be PropertyType, not PropertyEntry

## Status

**Accepted**

## Context

The output schema system uses the `PropertyEntry` class to define the structure of tool outputs. For array types, the `items` field previously accepted a `PropertyEntry` instance, allowing for nested property definitions. However, the intended use case is to specify the type of items within the array, not their full schema. The output schema should describe the expected type of array elements, not their structure or content, to match JSON Schema conventions and simplify consumer logic.

## Decision

Change the type of the `items` field in `PropertyEntry` from `PropertyEntry?` to `PropertyType?`. This ensures that when defining an array property, only the type of the items (e.g., string, number, boolean) is specified, rather than a full property schema.

## Consequences

### Positive
- **POS-001**: Output schema for arrays will correctly specify the type of items using `{ "items": { "type": "string" } }`, matching JSON Schema expectations.
- **POS-002**: Simplifies schema definition and avoids confusion between item type and item structure.
- **POS-003**: Tool consumers can reliably infer the type of array elements without parsing nested property definitions.

### Negative
- **NEG-001**: Reduces flexibility for describing complex item structures in arrays (if ever needed).
- **NEG-002**: May require future extension if nested schemas for array items are needed.
- **NEG-003**: Migration required for any code relying on the old PropertyEntry-based items field.

## Alternatives Considered

### Use PropertyEntry for items
- **ALT-001**: **Description**: Allow items to be a full PropertyEntry, enabling nested schemas for array elements.
- **ALT-002**: **Rejection Reason**: Overly complex for current use case; output schema only needs to specify item type, not structure.

### Use dynamic or Map for items
- **ALT-003**: **Description**: Use a dynamic type or Map to allow arbitrary item definitions.
- **ALT-004**: **Rejection Reason**: Reduces type safety and clarity; PropertyType is sufficient and aligns with JSON Schema.

## Implementation Notes
- **IMP-001**: Update PropertyEntry class and all usages to use PropertyType for items.
- **IMP-002**: Refactor array property construction and serialization logic to output correct JSON Schema.
- **IMP-003**: Update documentation and migration guides for consumers.

## References
- **REF-001**: ADR-0001: Structured OutputSchema Implementation and Code Cleanup
