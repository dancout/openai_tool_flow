# ROUND 7

I need your help with the following content.

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
- [ ] Refactor the `AuditFunction` base class to support generics, allowing it to be defined as `AuditFunction<T extends ToolOutput>`.
    - The `run` method should accept a parameter of type `ToolResult<T>`, so that specialized audit functions (e.g., `ColorQualityAuditFunction`) can safely access properties specific to their output type (e.g., `result.output.colors` on `ToolResult<ColorsToolOutput>`).
    - Update `ToolResult` to be generic as `ToolResult<T extends ToolOutput>`, ensuring the output is strongly typed and accessible.
    - Update all audit function implementations to specify their expected `ToolOutput` subtype.
    - Ensure the interface remains consistent and discoverable for all audit functions, while providing type safety and flexibility for specialized logic.
    - Feel free to refactor any other functions to use this `<T>` or `<T extends {something}>` notation if you believe it is better, or need it in order to finish your work.
- [ ] Update the DefaultOpenAiToolService._buildToolDefinition function to make the open ai tool call's response conform to our expected ToolOutput
    - I believe that what is happening is that we are using the ToolInput to create a schema and then forcing the tool call's response to conform to that, which will almost certainly fail.
    - The flow should instead be that we force the open ai tool call to conform to an expected ToolOutput so that we can know we'll receive exactly that output after the call.
        - Keep in mind that the tool call's raw data response will potentially be run through a sanitizeOutput function, but the expected keys should all still be the same
            - For example, we may specify the expected output to be `{"colorVal": {"type": "string"}}`, and from the tool call it comes back as "FFFFFF", but we NEED it to be prefixed with a "#" for our code to work, so the sanitizer might just add a # making it "#FFFFFF".
                - Even though the data has changed, the structure of the output schema was the same.
    - I'm not sure if it makes more sense to include a schema on the ToolCallStep or the StepConfig itself, or have a function you need to pass in that will generate that schema or what.
        - Ponder on this and do what makes the most sense, making it most understandable for the user interfacing in with our package. 


### FINAL REQUIREMENTS
- [ ] Please update all relevant existing tests or create new ones for new functionality before officially completing your work.
- [ ] Ensure any necessary ADR files are generated for core decisions made from the above requests.
    - Also update the `adr_references` and `used_as_resource_in` sections of the relevant ADRs so that we know which ADRs have been used in the future.
- [ ] There should be no linting errors or warnings when you are finished with your work.
    - You can run "dart analyze" to see all the linting errors and warnings.
- [ ] Ensure all completed requests have been committed to the PR Branch before moving beyond this task
- [ ] Add an entry in the docs/adr_appendix.md for each of the ADR files that were created above
