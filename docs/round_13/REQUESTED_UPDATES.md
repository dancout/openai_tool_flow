# ROUND 13

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
- [ ] Replace the `includeOutputsFrom` parameter on `StepConfig` with `includeResultsInToolcall` with an optional severity level filter
    - The context here is that we want be able to pull forward previous results & their associated issues to pass into the open ai tool call so that the pipeline does not repeat previous issues.
        - However, we don't want to always include all results and all issues because that would be token bloat and not always relevant
    - The user should be able to specify from which steps they'd like to include both the tool's output and associated issues (we should simply ignore the tool's input for now)
    - The user should be able to specify a severity level of which issues to filter on
        - ie. If the severity level filter was `IssueSeverity.medium` then all issues of type medium and higher would be included
        - If there are no issues of a filtered level or higher associated with a step's output result, then there is nothing to add. Don't add anything else to the system message, either.
            - We are interested in showing "here's what you did previously and why it was wrong".
        - The severity level should default to high.
- [ ] What should be done for the user is that the tool's output and associated issues should be neatly & consistently parsed and placed into the system message going into the open ai tool call.
    - There was existing code on this, but was removed, and you can see the below code snippet for context:
```dart
 // TODO: I wonder if we should have a convenience function that can convert the issues from previous results to be easily used in the future. The context here is that if we are doing a tool call that is adjusting the values of a TypedOutput then we may be interested in the previous issues as to not regress and recreate them.
    /// So, it might be nice to be able to simply say "include the previous results and issues from these steps" and the user doesn't have to parse everything themselves. Either through like an overridable method, or a getter, or even just passing in a list to a parameter that says "include these bad boys".
    /// The removed code from the _buildSystemMessage was:
     if (input.previousResults.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Previous step results and associated issues:');
      for (int i = 0; i < input.previousResults.length; i++) {
        final result = input.previousResults[i];
        buffer.writeln(
          '  Step ${i + 1}: ${result.toolName} -> Output keys: ${result.output.toMap().keys.join(', ')}',
        );

        // Include issues associated with this specific result
        if (result.issues.isNotEmpty) {
          buffer.writeln('    Associated issues:');
          for (final issue in result.issues) {
            buffer.writeln(
              '      - ${issue.severity.name.toUpperCase()}: ${issue.description}',
            );
            if (issue.suggestions.isNotEmpty) {
              buffer.writeln(
                '        Suggestions: ${issue.suggestions.join(', ')}',
              );
            }
          }
        }
      }
    }
```
    - So, the user should ONLY have to specify which outputs to include with their associated issues, and the package takes care of th erest under the hood.
    - Note Look at `ToolFlow._getInputBuilderResults` on the logic that was used to parse which results to use.
        - Consider ways to consolidate this logic as to not repeat code in multiple places.

### FINAL REQUIREMENTS
- [ ] Please update all relevant existing tests or create new ones for new functionality before officially completing your work.
- [ ] Ensure any necessary ADR files are generated for core decisions made from the above requests.
    - Also update the `adr_references` and `used_as_resource_in` sections of the relevant ADRs so that we know which ADRs have been used in the future.
- [ ] There should be no linting errors or warnings when you are finished with your work.
    - You can run "dart analyze" to see all the linting errors and warnings.
- [ ] Ensure all completed requests have been committed to the PR Branch before moving beyond this task
- [ ] Add an entry in the docs/adr_appendix.md for each of the ADR files that were created above
