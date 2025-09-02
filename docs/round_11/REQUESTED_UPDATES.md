# ROUND 11

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
- [ ] Make `ToolOutputRegistry.create` return a non-optional `ToolOutput`.
    - If there is any issue, or cannot find the ToolOutput, then the function should throw
    - The `ToolFlow` file's `_executeStep` no longer needs to wrap `final trialTypedOutput = ToolOutputRegistry.create(...` in a rty catch block and check if the output is null. It can just run it, expecting a valid `ToolOutput`.
- [ ] Make `ToolOutputRegistry.getOutputType` return a non-optional `Type`
    - Similar to above, if there is any issue or it cannot find the `Type`, then the function should throw
    - We should not be defaulting to a generic `ToolOutput` if we can't find the `Type`, because we will have lost out on exactly what `Type` we were expecting.
        - Referencing `ToolOutputRegistry.getOutputType(step.toolName) ?? ToolOutput;`
- [ ] Convert `get results` on `ToolFlow` to return a `List` of `TypedToolResult` instead of the legacy `ToolResult<ToolOutput>`
    - You should update anything dependent on this `results` getter to handle the new return type.
- [ ] `ToolFlow.issuesWithSeverity` should not live on `ToolFlow`
    - It is only used in the example code as a convenience function.
    - Move the logic to filter issues with a severity to the level it is needed in the `usage.dart` file.
- [ ] `ToolOutput` should have the round number as a required parameter
    - This represents which round, or attempt, this `ToolOutput` was created in during the `ToolFlow` progression.
- [ ] Ensure proper unit tests are written regarding all of the above changes
    - This includes ensuring that exceptions are thrown when expected

### FINAL REQUIREMENTS
- [ ] Please update all relevant existing tests or create new ones for new functionality before officially completing your work.
- [ ] Ensure any necessary ADR files are generated for core decisions made from the above requests.
   - Also update the `adr_references` and `used_as_resource_in` sections of the relevant ADRs so that we know which ADRs have been used in the future.
- [ ] There should be no linting errors or warnings when you are finished with your work.
   - You can run "dart analyze" to see all the linting errors and warnings.
- [ ] Ensure all completed requests have been committed to the PR Branch before moving beyond this task
- [ ] Add an entry in the docs/adr_appendix.md for each of the ADR files that were created above
