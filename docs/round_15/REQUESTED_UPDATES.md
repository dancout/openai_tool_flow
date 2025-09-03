# ROUND 15

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
- [ ] Ensure that in the pipeline used within usage.dart, we are retrying a maximum of 3 times in each step call.
    - So, probably pass in explicitly the maxRetries
- [ ] Make this example flow a little more impressive or like a real scenario where the steps build off one another. The goal is to show that the tool calls are working and not just spitting out garbage.
    - For example, we shouldn't be going from 8 refined colors down to 4 for the final theme.
    - Also, the theme just lists 4 colors but doesn't specify anything as primary, background, error, warning, etc.
    - Proposed new flow
        - Step 1 --> generate 3 random colors for the seed palette
        - Step 2 --> Using above step output, generate 4-8 main colors for each category of a design system
            - You should choose an actual number between 4 and 8, I'm just spitballing
            - These will represent things like surface, text, warning, error, etc
        - Step 3 --> Using above step output, generate a full suite of design system colors
            - Should be something like 20-40 different color specifications (again, choose an actual number, I just gave a range)
            - These are going to be things like primaryText, interactiveText, expressiveText, primaryBackground, errorBackground, warningBackground, etc
- [ ] Potentially update the system messages or what goes into them so that they are more catered to what you're doing in the step
    - For example, if we are on the color refinement palette, it might be good for the system message to tell the llm "hey, you're an expert UX designer with a deep understanding of color theory. You'll be responsible for expanding color families" or something like that. Use your best judgement.
        - I'm not sure if this should go in the system message, or the user message, or the tool call description, or any combination of those entries. Again, use your best judgement to get the important information to the tool call in a structured way that makes sense, and is still easy for the user who is consuming this package to define.

### FINAL REQUIREMENTS
- [ ] Please update all relevant existing tests or create new ones for new functionality before officially completing your work.
- [ ] Ensure any necessary ADR files are generated for core decisions made from the above requests.
    - Also update the `adr_references` and `used_as_resource_in` sections of the relevant ADRs so that we know which ADRs have been used in the future.
- [ ] There should be no linting errors or warnings when you are finished with your work.
    - You can run "dart analyze" to see all the linting errors and warnings.
- [ ] Ensure all completed requests have been committed to the PR Branch before moving beyond this task
- [ ] Add an entry in the docs/adr_appendix.md for each of the ADR files that were created above
