# ROUND 18

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
- [ ] Update the storage of token usage within `ToolFlow` to be on a structured object that stores all token usage data
    - This object should be included on each `TypedToolResult` object.
    - Initial input data should show all zeros, since that wasn't created using an actual tool call (Read up on the ADRs if you are confused about what this means)
- [ ] Update `ToolFlow` internal logic so that we don't have both `_results` and `_allAttempts`. Consolidate to one single internal collection.
    - We only need 1, since `_results` is a subset of `_allAttempts`
    - This consolidated collection should have a type of `List<List<TypedToolResult>>`, where the index represents the step that was run.
        - NOTE: The initial input data should still be the first entry, and that will likely just be a single attempt since we are just converting the input to an output and passing it forward.
- [ ] ToolFlow parameter value on whether to include token usage on TypedToolResult
    - A user may want to save on memory or execution time by not storing these things as they go
    - Default to true
- [ ] ToolFlow parameter value on whether to include all Attempts in the `ToolFlowResult.results`
    - If this parameter is false, then only return the final attempt of each step
    - If this parameter is true, then return all attempts of each step
    - Default to true
    - The output type of `ToolFlowResult.results` should now be `List<List<TypedToolResult>>`
- [ ] Devise a way to more consistently and safely get the stepIndex or resultIndex instead of doing `i - 1`, `i`, or `i + 1` when getting entries for each step or result from things like `_results`, `state`, `finalState`, `_allAttempts`, `steps`, and any other list, map, or collection of objects relating to a step level.
    - This is so that whenever we are trying to get step 1 stuff, as a developer I know that dart lists are 0 indexed so I would think to get the results at index 0 for step 1 results BUT the index 0 of results is actually the input of the run function converted into an output, and that may get confusing.
    - Be sure to add plenty of documentation around whatever you decide to do so that it's clear to the end user what they are doing.
- [ ] The "maxRetries_used" within the `stats` map in the `_exportEnhancedResults` function in the `usage.dart` file should actually find how many retry attempts were used across all steps instead of being hardcoded.
- [ ] `ToolFlowResult` should not have `allIssues` in its constructor, since that can be derived from the `typedResults` it already has.
    - `allIssues` could exist as a getter on the instance of the `ToolFlowResult` if we wanted.
- [ ] In `ToolFlow` consolidate the logic used to filter `TypedToolResult attempt` objects from a list of previous results and call that helper function when getting the current step attempts and the included results
    - Currently, we've effectively copy and pasted code in `_getIncludedResults` and `_getCurrentStepAttempts`


### FINAL REQUIREMENTS
- [ ] Please update all relevant existing tests or create new ones for new functionality before officially completing your work.
- [ ] Ensure any necessary ADR files are generated for core decisions made from the above requests.
    - Also update the `adr_references` and `used_as_resource_in` sections of the relevant ADRs so that we know which ADRs have been used in the future.
- [ ] There should be no linting errors or warnings when you are finished with your work.
    - You can run "dart analyze" to see all the linting errors and warnings.
- [ ] Ensure all completed requests have been committed to the PR Branch before moving beyond this task
- [ ] Add an entry in the docs/adr_appendix.md for each of the ADR files that were created above

