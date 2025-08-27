# ROUND 6

I need your help with the following content.

### Instructions
- Please fulfill each of the requested updates for each section below.
- There are some ambiguous directions that you can interpret freely.
- Use the `ADR_TEMPLATE.md` file to generate decisions records you've made about the below requested changes
    - Documenting your decisions is critical for future requested updates so that we understand why certain decisions were made
    - You should name the ADR file(s) accordingly, or better yet put them in a named directory, so that it is clear that they came from this request of changes
- You can view previous ADR files by looking in the docs/adr_appendix.md file, which contains the title, round number, key words, and quick summary of each ADR.
- You should be able to install dart on your VM, and have done so before. The log output from when you did this can be found at /docs/install_dart_logs.txt
- There should be no linting issues or warnings when you are finished with your work.
- Please update all relevant existing tests or create new ones for new functionality before officially completing your work.
- Be sure to commit at checkpoints throughout your work so that in the event of an error in your process, all your good work is not lost.
- When adding comments, do so for the sake of good documentation and not for the sake of letting the user know you were following instructions.
- You do not need to worry about backwards compatibility, so don't keep legacy code and make the codebase more bloated. We are still working on version 0.0, so feel free to make breaking changes.

### REQUESTS
- [ ] Go through the lib/src directory and convert any method that takes more than 1 parameter to use named parameters
    - It is easier to understand exactly what parameter should be passed, especially with maps that could be a super or a subset of a collection.
- [ ] Update the `ToolResult` to require a `TypedInput` and `TypedOutput`, and you can do away with the `Map<string, dynamic> input` and `Map<String, dyanmic> output`.
    - We are just using the ToolInput.toMap() for the Map version of `input` anyway, which is redundant. It feels like this could be a cleaner interface from the super project is we MUST specify EXACTLY what is going in and out of each tool call.
- [ ] Update the `ToolCallStep` to no longer take in `params` and instead have a required `inputBuilder`.
    - Look at the TODO in the `usage.dart` file for the context here. We cannot possible know the input params for step 2, especially if it is dependent on step 1. A better way of doing this would be to specify how to transform the output of step 1 into the input of step 2 once that data becomes available.
    - The `ToolCallStep` should have a param similar to `includeOutputsFrom` that is called `buildInputsFrom`
    - The `inputBuilder` will be a function that takes in a `List<ToolResult>` which will be the list in order from `buildInputsFrom`
    - This `inputBuilder` will return a structured object (sort of like a minimized ToolInput) which will be what is passed to the `_buildStepInput` function within `ToolFlow`
        - We need a new structured object because the `ToolInput` object itself has things like `round`, `previousResults`, `temperature`, and other params that I don't want the user to have to worry about filling into the object within their `inputBuilder`.
            - They should be concerned with the least amount of data as possible for simplicity.
            - The `ToolInput` object could even take a parameter which is the new above structured object, containing all the same data (I think the data in question is what used to be in `step.params`)
    - If there are no entries in `buildInputsFrom`, then the user could easily directly specify what their input going into that step should be, still in the `inputBuilder`, effectively setting the `List<ToolResult>` to an underscore an ignoring it.
    - The `sanitizeInput` method probably goes away now, since the user now has pretty direct access into how the input is being build with the `inputBuilder`.
        - However, I'm leaving it up to your best judgement if you think that the `sanitizedInput` still serves a good purpose (such as because it could sanitize data coming from the `_state.entries` within `ToolFlow`). Either way, consider creating an ADR about it.
    - The `includeOutputsFrom` functionality should remain unchanged.


### FINAL REQUIREMENTS
- [ ] Ensure any necessary ADR files are generated for core decisions made from the above requests.
- [ ] Ensure all completed requests have been committed to the PR Branch before moving beyond this task
- [ ] Add an entry in the docs/adr_appendix.md for each of the ADR files that were created above
