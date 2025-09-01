# ROUND 9

I need your help with the following content.

### Instructions
- Please fulfill each of the requested updates for each section below.
- There are some ambiguous directions that you can interpret freely.
- Reference: Review any new ADRs or architectural decisions made in this round before starting implementation.
- Use the `ADR_TEMPLATE.md` file to generate decisions records you've made about the below requested changes.
    - Documenting your decisions is critical for future requested updates so that we understand why certain decisions were made.
    - You should name the ADR file(s) accordingly, or better yet put them in a named directory, so that it is clear that they came from this request of changes.
- You can view previous ADR files by looking in the docs/adr_appendix.md file, which contains the title, round number, key words, and quick summary of each ADR.
- Be sure to commit at checkpoints throughout your work so that in the event of an error in your process, all your good work is not lost.
- When adding comments, do so for the sake of good documentation and not for the sake of letting the user know you were following instructions.
- You do not need to worry about backwards compatibility, so don't keep legacy code and make the codebase more bloated. We are still working on version 0.0, so feel free to make breaking changes.
- Do not remove existing TODOs unless you are directly addressing them.
- Do not add convenience functions or classes "just in case".
    - Only add code that you fully intend on using. Otherwise, multiple getters or factory methods that are never again referenced are simply bloating the codebase.

### REQUESTS
- [ ] Remove all unused functions or methods across the codebase
    - Includes any convenience methods marked "visibleForTestings"
        - If there is a use case for something to be visibleForTesting, such as it is needed for a unit test, then that is acceptable
    - Includes any static getters like "nonBlockingConfig" that aren't used functionally or for the example code
    - There is a lot of bloat code in this codebase and we should keep things tight and clean
- [ ] Make the outputSchema on StepConfig be a structured object
    - it should have 3 parameters
        - type (string or enum of acceptable types)
        - properties (list of PropertyEntry type)
            - The PropertyEntry type should be a structured object that defines that property's type, optionally items, description, and anything else you can think on that's necessary for a property entry (if applicable)
        - required (list of string)
- [ ] Related to the above point, make the OutputSchema more tightly coupled with the expected ToolOutput for a Tool Call Step.
    - You could build the properties from the already defined ToolOutput
        - You could leverage the existing ToolOutput.toMap for this
    - It could now become optional to pass an outputSchema to the StepConfig if you'd like to override the tool call's expected output schema
- [ ] Again releated to the above, the intention here is that the user should no longer need to specify the output schema while specifying the step configs (if possible. Don't bend over backwards trying to fulfill this task)
    - I think most of this should be easy to do, other than the required properties portion, but I trust you'll be clever.
    

### FINAL REQUIREMENTS
- [ ] Please update all relevant existing tests or create new ones for new functionality before officially completing your work.
- [ ] Ensure any necessary ADR files are generated for core decisions made from the above requests.
    - Also update the `adr_references` and `used_as_resource_in` sections of the relevant ADRs so that we know which ADRs have been used in the future.
- [ ] There should be no linting errors or warnings when you are finished with your work.
    - You can run "dart analyze" to see all the linting errors and warnings.
- [ ] Ensure all completed requests have been committed to the PR Branch before moving beyond this task
- [ ] Add an entry in the docs/adr_appendix.md for each of the ADR files that were created above
