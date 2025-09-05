# ROUND 16

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
- [ ] Update `ToolCallStep.inputBuilder` to be an optional parameter.
    - If no `inputBuilder` is specified, then the `Map` passed forward defaults to the previous step's `TypedToolResult` transformed into a map, likely using its `toMap()` function.
    - So, we will effectively be passing the previous step's output directly forward as the input for the current step
- [ ] Update the `ToolFlow.run` function to require the input parameter instead of defaulting to an empty map.
    - This input Map should then be converted to a `TypedToolResult` where it's type T can just be `ToolOutput`, and the input map will be used at the `ToolOutput._data` object.
        - You can make this same `input` map be reflected as the `ToolInput.customData`
    - Any of the nested values can be populated based on the fact this is an initial input, so any params should reflect that (like the step or tool name should be initial_input). This may be relevant for things like the required ToolInput object on the `ToolResult`.
- [ ] `buildInputsFrom` should go away in favor of pulling all previous results forward for the `inputBuilder`'s `previousResults` parameter.
    - In other words, instead of needing to pick and choose which previous results should move forward, the `inputBuilder` should have access to the entire list of previous results.
- Update how`ToolCallStep.includeResultsInToolcall` works so that it only accepts an integer which will be the index of the previous results to pull from.
    - Purge all references to how we were pulling previous results by tool or step name.
        - This includes updating any documentation referencing this.
    - The order should be the 0 index being the very first `TypedToolResult` and the last index being the last `TypedToolResult` before the current step
        - In other words, the `input` map going into the `ToolFlow.run` call will create a `TypedToolResult` that will be the 0 index of the `previousResults`, and the `TypedToolResult` output from the first `ToolCallStep` will become the 1 index, and so on.
- [ ] We shuld be optionally able to specify `maxTokens` for the open ai tool call per each step.
    - This will likely be added to the `StepConfig` and should default to whatever is in the `OpenAIConfig` if it is not specified. Not a required field.
- [ ] The `ToolCallStep.model` should be an optional field.
    - It should fall back on whatever is in the `OpenAIConfig`.
- [ ] Keep track of consumed tokens for each `ToolCallStep` within the `ToolFlow._state` map.
    - I want a breakdown of everything available in the `usage` key in provided example
    - You can see the open ai response structure in the `docs/open_ai_response.json` file.


### FINAL REQUIREMENTS
- [ ] Please update all relevant existing tests or create new ones for new functionality before officially completing your work.
- [ ] Ensure any necessary ADR files are generated for core decisions made from the above requests.
    - Also update the `adr_references` and `used_as_resource_in` sections of the relevant ADRs so that we know which ADRs have been used in the future.
- [ ] There should be no linting errors or warnings when you are finished with your work.
    - You can run "dart analyze" to see all the linting errors and warnings.
- [ ] Ensure all completed requests have been committed to the PR Branch before moving beyond this task
- [ ] Add an entry in the docs/adr_appendix.md for each of the ADR files that were created above

