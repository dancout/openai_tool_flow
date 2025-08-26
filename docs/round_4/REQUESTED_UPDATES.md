# ROUND 4

I need your help with the following content.

### Instructions
- Please fulfill each of the requested updates for each section below.
- There are some ambiguous directions that you can interpret freely.
- Use the `ADR_TEMPLATE.md` file to generate decisions records you've made about the below requested changes
    - Documenting your decisions is critical for future requested updates so that we understand why certain decisions were made
    - You should name the ADR file(s) accordingly, or better yet put them in a named directory, so that it is clear that they came from this request of changes
- You should be able to install dart on your VM, and have done so before. The log output from when you did this can be found at /docs/install_dart_logs.txt
- There should be no linting issues or warnings when you are finished with your work.
- Please update all relevant existing tests or create new ones for new functionality before officially completing your work.
- Be sure to commit at checkpoints throughout your work so that in the event of an error in your process, all your good work is not lost.

### REQUESTS
- [ ] Consolidate StepInput and ToolInput within the typed_interfaces.dart file
    - There is no reason for us to have both of these classes, and to be extending one or the other elsewhere in our package and the example directory. They are intended to be representative of the same base input class. The idea is that the super project would extend this base input class to add whatever else it needs. We may not need the base input to be abstracted, but rather to be extendable? I'm not sure, so please think on that.
    - Look at consolidating stepInput and typedInput within the _executeStep function or ToolResult class where it makes sense. It just feels redundant to set the typedInput object to the stepInput object and then do away with the stepInput and move forward with the typedInput.
- [ ] Only include the previousIssues for the includedOutputs for the _buildStepInput function
    - We are carefully choosing which previous outputs to carry forward for our tool call step creation, and that should extend to which previous issues to include. Only include the issues from the relevant included steps.
- [ ] StepInput should take in structured objects whenever possible
    - Namely, looking at previousIssues. We have an Issue object, and things should not be converted into a Map or JSON until absolutely necessary, so that way it is easier to work with structured data as long as possible.
- [ ] Create a copyWith method on ToolResult and use that whenever making changes only to a select few objects
    - An example is when we check if the stepConfig hasOutputSanitizer within ToolFlow, we then sanitize the output and create a whole new stepResult with only a different sanitized output
- [ ] Sanitize the ToolResult output before creating the typedOutput
    - If we have a sanitizeOutput function for the response data coming back from the API call, we should be calling that FIRST before creating a strongly typed, structured typedOutput object. That `ToolOutputRegistry.create` may very well be dependent on sanitized info.
