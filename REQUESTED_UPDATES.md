## REQUESTED UPDATES
I need your help with the following content:

- Please fulfill each of the requested updates for each section below.
- There are some ambiguous directions that you can interpret freely.

### Miscellaneous
- Use the `ADR_TEMPLATE.md` file to generate decisions you've made about the below requested changes
    - Documenting your decisions is critical for future requested updates so that we understand why certain decisions were made
    - You should name the ADR file(s) accordingly, or better yet put them in a named directory, so that it is clear that they came from this request of changes

### Pubspec
- I moved the dart version down from 3.9.1 to 3.8.1.
    - Please let me know if this was an issue, or if it absolutely needs to be at the higher dart version for this package to work.
        - If so, update the dart min version back to 3.9.1 and update why in an ADR.
    - The context is that I'm running flutter v3.32.8 locally, and it has dart 3.8.1 installed

### ToolCallStep
- Should accept a List of `Issue` objects instead of just `Map<String, dynamic>`, possibly by passing both `params` and `issues`.

### ToolResult
- Instead of using a generic `Map<String, dynamic>`, define concrete result types for each tool call, such as `SeedPalette` with explicit parameters (`x`, `y`, `z`, etc.).
- Ensure that the output schema for each tool is well-defined and strongly typed, so downstream steps can reference specific fields reliably.
- Consider using an abstract base class or interface for extensibility, but prioritize clear, explicit result types over generic maps.
- Similarly, input schemas should be concrete types that match the expected structure for each tool call, rather than using `Map<String, dynamic>`.
- This approach enables precise typing and validation when integrating with the OpenAI API and referencing results in subsequent steps.

### AuditFunction
- Move the `SimpleAuditFunction` implementation to the example directory, not the core package.
- You may keep `List<Issue> Function(ToolResult) auditFunction` in the abstract class if useful, unless you think it should be excluded for flexibility.

### ToolFlow
- Audits should be assigned to specific steps, not run on every step.
    - For example: Audit1 on step1, Audit1 & Audit2 on step2, none on step3, Audit3 on step4, etc.
- Avoid relying on `_mockToolCalls`; instead, allow specifying expected outputs for ToolCalls.
    - Implement ToolFlow to work with actual OpenAI SDK tool calls, but keep `_mockToolCall` for now.
- Audit results must be checked to ensure criteria are met before proceeding.
    - If criteria are not met, retry up to X times (X configurable, default in ToolCallStep).
    - Allow the importing project to specify pass/fail criteria.
        - Use the `Issue` object’s severity to determine pass/fail, e.g., any critical issue fails, or use a weighted threshold.
        - This function should be overrideable by the importing project.
        - Alternatively, the `AuditFunction` class can have an abstract `passedCriteria(List<Issue>)` method to return pass/fail, or an object with a reason for failure.

### Issue
- Track which "round" or "run" an issue came from, and optionally the relevant input/output.
    - This helps avoid regressing to old issues after retries, but keeps context of previous issues.

### Example Usage File
- Use `ColorQualityIssue` in implemented audit classes, not just declare it.
- Specify expected inputs and outputs for each `ToolCallStep` in the example file.
    - Show how to define what each `ToolCallStep` expects for input and output.