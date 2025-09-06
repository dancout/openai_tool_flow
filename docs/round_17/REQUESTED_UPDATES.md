# ROUND 17

I need your help with the following content.

### IMPORTANT
- This is still a version 0.0.x package, so we should not worry about backwards compatibility
    - If you need to make a breaking change, make the breaking change
    - Needing to do lots of refactors is NOT a valid reason not to implement a change

### Instructions
- Please fulfill each of the requested updates for each section below.
- There are some ambiguous directions that you can interpret freely.
    - Feel free to be creative with your solution if you completely understand the context of what the user is asking for and need to do something potentially complex to accomplish it.
    - Saying something is too complex or not backwards compatible is not an acceptable reason not to do something (especially since we do not have a production app yet, so backwards compatibile isn't relevant yet - just make the change!)
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
- [ ] Read the below section "Raw user input received to generate these requests." for exact context given by the user on these requests.
- [ ] Store all outputs and their corresponding issues for every retry attempt of each step, not just the final result.
- [ ] Update the system so that, when building the system message in `DefaultOpenAiToolService._buildSystemMessage`, both the output and issues from each relevant attempt (including retries) are included.
- [ ] Clearly distinguish in the system message which outputs/issues are from previous steps and which are from retries of the current step.
- [ ] Apply the Issue Severity filter to determine which outputs and issues from retries are included in the system message.
- [ ] Ensure that `includeResultsInToolcall` correctly provides previous results (with filtered issues) to the system message, and verify this with a test case where a high-severity issue is intentionally triggered.

### FINAL REQUIREMENTS
- [ ] Please update all relevant existing tests or create new ones for new functionality before officially completing your work.
- [ ] Ensure any necessary ADR files are generated for core decisions made from the above requests.
    - Also update the `adr_references` and `used_as_resource_in` sections of the relevant ADRs so that we know which ADRs have been used in the future.
- [ ] There should be no linting errors or warnings when you are finished with your work.
    - You can run "dart analyze" to see all the linting errors and warnings.
- [ ] Ensure all completed requests have been committed to the PR Branch before moving beyond this task
- [ ] Add an entry in the docs/adr_appendix.md for each of the ADR files that were created above

---

## Raw user input received to generate these requests.

When there are issues related to outputs, we should be able to access both the output AND the corresponding issues from that particular output. Simply seeing the final output and all the accumulated issues is not acceptable because we are missing the context of why that issue may have arisen in the first place.

When calling DefaultOpenAiToolService._buildSystemMessage we should be able to also add the previous output alongside the previous issues.

I also think that it might be the case that the input's previousIssues that we are iterating over are the previousResults being pulled forward from includeResultsInToolCall. This is fine, but we should also have the output and the issues from the retry or retries of the current step included in the system message. It should also be clear (probably in the text written to system message) which set of output and issues were from previous steps and which were from this step.

The Issue Severity filter should also apply to which sets of outputs & issues are included from the retries of this step.

I'm also not confident that pulling previousResults with their filtered issues is actually working based on the local testing I was doing (I was forcing a high severity issue on the first attempt on ColorDiversityAuditFunction just so that the result would have an associated issue, but then even when having includeResultsInToolcall: [0, 1] for the designSystemStep it was never seeing any previous results on input.previousResults within openai_service_impl._buildSystemMessage).
