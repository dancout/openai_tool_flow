# ROUND 22

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
- [ ] **Implement Local Step Execution**: Add support for steps that can be executed locally without making LLM API calls.
    - **Context**: For certain operations (e.g., generating color variations by mathematically adjusting hex values), it makes more sense to compute results locally rather than consuming tokens and risking LLM hallucinations.
    - **Requirements**:
        - Create a way to define a step that executes locally (similar to ToolCallStep but without LLM invocation)
        - The local step should maintain the same interface as much as possible (e.g., define expected output schema, support audits, retries if applicable)
        - Local step results should be available to downstream steps via input builders just like LLM-generated results
        - The step should produce a ToolResult with the same structure as LLM steps for consistency in the flow
        - Consider naming: `LocalStep`, `ComputedStep`, `SyntheticStep`, or similar
    - **Use Case Example**: 
        - Step 1: LLM generates 5 base colors
        - Steps 2-6: Locally compute 4 variations of each base color by adjusting hex values
        - Step 7: LLM uses all colors (base + variations) to generate a comprehensive design system
    - **Design Considerations**:
        - Should support the same retry logic as LLM steps (in case local computation fails validation/audits)
        - Should track that no tokens were used (TokenUsage.zero())
        - Should fit seamlessly into the existing ToolFlow execution model
        - Consider whether the local computation function should be sync or async
        - Determine if local steps need tool names/descriptions (probably yes for consistency)

### FINAL REQUIREMENTS
- [ ] Please update all relevant existing tests or create new ones for new functionality before officially completing your work.
- [ ] Ensure any necessary ADR files are generated for core decisions made from the above requests.
    - Also update the `adr_references` and `used_as_resource_in` sections of the relevant ADRs so that we know which ADRs have been used in the future.
- [ ] There should be no linting errors or warnings when you are finished with your work.
    - You can run "dart analyze" to see all the linting errors and warnings.
- [ ] Ensure all completed requests have been committed to the PR Branch before moving beyond this task
- [ ] Add an entry in the docs/adr_appendix.md for each of the ADR files that were created above
