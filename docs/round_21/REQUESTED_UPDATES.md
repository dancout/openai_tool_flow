# ROUND 21

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
#### Do this first
- [ ] Read "ToolFlow_Architecture.md" to understand how the toolflow pipeline works

#### Do this next
- [ ] Support edit image request through open ai tool call
    - This request will be a POST to https://api.openai.com/v1/images/edits
        - So, the base URL can still come from env, just be sure to hit image edit instead of chat completions.
    - You can see the copy & pasted documentation for the create image call in the "round_21/edit_image_documentation.txt" file
    - You can see a copy of the example request in "round_21/example_request.txt" file
    - You can see a copy of the example response in "round_20/example_response.json" file
        - Note: this is the same expected response as when you create an image
- [ ] There should be as much re-used code for the tool calling process as possible
    - The intention is not to create an entirely new pipeline for image edits, but rather for image edits to be another option within the existing pipeline
        - With this being said, there will likely need to be some new pieces put in place to support image edits, and that is alright.
            - Be sure to create an ADR document explictily explaining any changes or new piepline features you add for supporting image edits
- [ ] You likely will need to update the process of determining if a step is meant for image generation, image edits, or chat completions to be more sophisticated than simply looking at the model used
    - For context, solely based on dall-e-2, how would you know that the steps intention is for image generation vs image editing?
    - It may be a good idea to consider making factory methods at the StepDefinition, or ToolCallStep, or ToolInput layer (I'm not sure which one, so please investigate). The thought there is that we can then have some parameter on the object that specifies which of the 3 types of tool call requests we are dealing with, but the factory method removes the possibility of a user making a mistake when building the object. The factory methods would be intended to make the actual constructor private (probably) and only expose chat, imageGen, or imageEdit options.
- [ ] Update the image_usage.dart file so that we are creating an image and then the second step should be running an edit on it

#### Do this last
- [ ] Update "ToolFlow_Architecture.md" to reflect any changes you've made

### FINAL REQUIREMENTS
- [ ] Please update all relevant existing tests or create new ones for new functionality before officially completing your work.
- [ ] Ensure any necessary ADR files are generated for core decisions made from the above requests.
    - Also update the `adr_references` and `used_as_resource_in` sections of the relevant ADRs so that we know which ADRs have been used in the future.
- [ ] There should be no linting errors or warnings when you are finished with your work.
    - You can run "dart analyze" to see all the linting errors and warnings.
- [ ] Ensure all completed requests have been committed to the PR Branch before moving beyond this task
- [ ] Add an entry in the docs/adr_appendix.md for each of the ADR files that were created above

