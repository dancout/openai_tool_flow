# ROUND 5

I need your help with the following content.

### Instructions
- Please fulfill each of the requested updates for each section below.
- There are some ambiguous directions that you can interpret freely.
- Use the `ADR_TEMPLATE.md` file to generate decisions records you've made about the below requested changes
    - Documenting your decisions is critical for future requested updates so that we understand why certain decisions were made
    - You should name the ADR file(s) accordingly, or better yet put them in a named directory, so that it is clear that they came from this request of changes
- You can view previous ADR files by looking in the docs/adr_appendix.md file, which contains the title, round number, key words, and quick summary of each ADR.
- Favor named parameters over positional parameters when declaring methods.
- You should be able to install dart on your VM, and have done so before. The log output from when you did this can be found at /docs/install_dart_logs.txt
- There should be no linting issues or warnings when you are finished with your work.
- Please update all relevant existing tests or create new ones for new functionality before officially completing your work.
- Be sure to commit at checkpoints throughout your work so that in the event of an error in your process, all your good work is not lost.
- When adding comments, do so for the sake of good documentation and not for the sake of letting the user know you were following instructions.
- You do not need to worry about backwards compatibility, so don't keep legacy code and make the codebase more bloated. We are still working on version 0.0, so feel free to make breaking changes.

### REQUESTS
- [ ] Consolidate StepInput and ToolInput so there is only one, single class
    - Choose whichever one makes sense. We should not be using any type-alias for this sort of thing. Previously we did most of the consolidation work, but both classes were still left in existence.
- [ ] If the code `typedOutput = ToolOutputRegistry.create(step.toolName, sanitizedOutput);` fails within the try bloc within ToolFlow's _executeStep, then the step should fail instead of silently catching
    - If the user has taken the time to specify a TypedOutput conversion function, that is likely for a good reason. Don't just silently fail. If typed conversion fails, the step should fail as well.
- [ ] Update all private methods within ToolFlow to favor named parameters over positional arguments.
    - This makes it more clear exactly what the method is expecting. ie. if we see that we're passing a list of issues into a method, I'm interested to know if it should be a filtered list or the entire list.
- [ ] Update ToolInput so that it intakes a `List<ToolResult> previousResults` instead of `List<Issue> previousIssues`
    - This is because the `ToolResult` object both contains the list of `Issue` objects associated with that that result and it contains the `TypedOutput` output from that result
- [ ] Update DefaultOpenAiToolService so that it passes around the `List<ToolResult>` instead of two separate `previousResults` and `relevantIssues` Lists. Also, update the `_buildSystemMessage` to construct the message being passed to the tool call in a way that makes it abundantly clear which outputs map to which issues.
    - The `SystemMessageInput` object will likely need updates to intake `previousResults` instead of the other two Lists, as well.
    - Update any other classes or definitions that make sense so that we aren't holding on to 2 lists instead of 1.
    - Do not convert these entities into JSON until the absolute last moment, which is likely within `_buildOpenAiRequest` since that is the function just before making the API request
        - We want to favor structured objects over unstructured objects for understandability and safety when passing objects around.
- [ ] Update any references to including outputs or previous issues to favor the `previousResults` within `tool_flow.dart`
    - Remember to remove any unused private functions, as well.
    - Feel free to update files outside of `tool_flow.dart` if they are relevant to these changes