# ROUND 20

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
#### COMPLETE THIS FIRST
- [ ] Read through the ToolFlow pipeline and all its underlying source files, and write up a markdown file explaining how the flow works, from user input to tool call step data manipulation to conversions to open ai api tool calls to the final ToolFlowResult.
    - Call this file "ToolFlow_Architecture.md" and place it at the root of the directory

#### COMPLETE THIS SECOND
- [ ] Support create image request through open ai tool call
    - This request will be a POST to https://api.openai.com/v1/images/generations
        - So, the base URL can still come from env, just be sure to hit image generations instead of chat completions.
    - You can see the copy & pasted documentation for the create image call in the "round_20/create_image_documentation.txt" file
    - You can see a copy of the example request in "round_20/example_request.txt" file
    - You can see a copy of the example response in "round_20/example_response.json" file
- [ ] There should be as much re-used code for the tool calling process as possible
    - The intention is not to create an entirely new pipeline for image generaiton, but rather for image generation to be another option within the existing pipeline
        - With this being said, there will likely need to be some new pieces put in place to support image generation, and that is alright.
            - Be sure to create an ADR document explictily explaining any changes or new piepline features you add for supporting image generation
- [ ] Create a new "image_usage.dart" file in the /example directory that showcases the creating image functionality.
    - This might just be a single step ToolFlow, which is OK because it is meant to show the image functionality.
- [ ] Run all tests and be sure they continue to pass
- [ ] Write new tests to cover any new functionality
- [ ] Run the linter and/or dart analyzer to verify there are no linter warnings or errors
    - If there are any, correct them.

#### COMPLETE THIS LAST
- [ ] Update the "ToolFlow_Architecture.md" file to reflect the new image generation support

### FINAL REQUIREMENTS
- [ ] Please update all relevant existing tests or create new ones for new functionality before officially completing your work.
- [ ] Ensure any necessary ADR files are generated for core decisions made from the above requests.
    - Also update the `adr_references` and `used_as_resource_in` sections of the relevant ADRs so that we know which ADRs have been used in the future.
- [ ] There should be no linting errors or warnings when you are finished with your work.
    - You can run "dart analyze" to see all the linting errors and warnings.
- [ ] Ensure all completed requests have been committed to the PR Branch before moving beyond this task
- [ ] Add an entry in the docs/adr_appendix.md for each of the ADR files that were created above

