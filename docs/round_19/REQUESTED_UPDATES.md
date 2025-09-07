# ROUND 19

I need your help with the following content.

### IMPORTANT
- This is still a version 0.0.x package, so we should not worry about backwards compatibility
    - If you need to make a breaking change, make the breaking change
    - Needing to do lots of refactors is NOT a valid reason not to implement a change

### Instructions
- Please fulfill each of the requested updates for each section below.
- There are some ambiguous directions that you can interpret freely.
- Use the `ADR_TEMPLATE.md` file to generate decisions records you've made about the below requested changes
    - Documenting your decisions is critical for future requested updates so that we understand why certain decisions were made
    - You should name the ADR file(s) accordingly, or better yet put them in a named directory, so that it is clear that they came from this request of changes
- You can view previous ADR files by looking in the docs/adr_appendix.md file, which contains the title, round number, key words, and quick summary of each ADR.
- You should be able to install dart on your VM, and have done so before. The log output from when you did this can be found at /docs/install_dart_logs.txt
- Be sure to commit at checkpoints throughout your work so that in the event of an error in your process, all your good work is not lost.
- When adding comments, do so for the sake of good documentation and not for the sake of letting the user know you were following instructions.
- You do not need to worry about backwards compatibility, so don't keep legacy code and make the codebase more bloated. We are still working on version 0.0, so feel free to make breaking changes.
- Do not remove existing TODOs unless you are directly addressing them.
- Do not add convenience functions or classes "just in case".
    - Only add code that you fully intend on using. Otherwise, multiple getters or factory methods that are never again referenced are simply bloating the codebase.

### REQUESTS
- [ ] There should be a convenience getter on `ToolFlowResult` called `passesCriteria` that returns true all the final results have passed their audit criteria
    - NOTE: A step that does not have an audit specified should automatically pass by default
- [ ] Update `AuditFunction<T extends ToolOutput>().run(ToolResult<T> result)` method to intake a `ToolOutput` (it might need to be the `<T>` that extends `ToolOutput`, I'm really not sure. That's for you to investigate and figure out.)
    - The reasoning here is that we don't need the full result object to be able to audit the output.
    - More realistically, the full result object should depend on the audits of the output, specifying what issues came along with this and whether the output passes all audit criteria.
- [ ] Related to the above, each `TypedToolResult` should have a required input parameter called `passesCriteria` that specifies whether or not it has passed the audits
    - NOTE: A step that does not have an audit specified should automatically pass by default
    - This might entail that we need to run audit functions on the `ToolOutput` before we have our final values for the `TypedToolResult`.
- [ ] Related to the above requests, we should not be generating a `TypedToolResult` and then backfilling the audited issues on underlying result later.
    - We should be able to create a `TypedToolResult` from the start and know up front whether it passes criteria and what its issues were.
    - We will likely need to update how our internal logic works to accomplish this. For example, `_executeStep` may need to intake the stepConfig (or at least the list of audit functions) so that it can evaluate the audit functions on the `ToolOutput` immediately, and then assign the issues and whether the step has passed to the `TypedToolResult` directly.
        - This updated logic also may not necessary live in the `_executeStep`. If it makes more sense to exist in the other files of this package, then that's also fine.
- [ ] Update all tests to reflect these new changes, or create new tests for new functionality.
- [ ] Update any example files to reflect these new changes. There should be no linter warnings or errors.

### FINAL REQUIREMENTS
- [ ] Please update all relevant existing tests or create new ones for new functionality before officially completing your work.
- [ ] Ensure any necessary ADR files are generated for core decisions made from the above requests.
    - Also update the `adr_references` and `used_as_resource_in` sections of the relevant ADRs so that we know which ADRs have been used in the future.
- [ ] There should be no linting errors or warnings when you are finished with your work.
    - You can run "dart analyze" to see all the linting errors and warnings.
- [ ] Ensure all completed requests have been committed to the PR Branch before moving beyond this task
- [ ] Add an entry in the docs/adr_appendix.md for each of the ADR files that were created above

