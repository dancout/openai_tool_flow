# ROUND 8

I need your help with the following content.

### Instructions
- Please fulfill each of the requested updates for each section below.
- There are some ambiguous directions that you can interpret freely.
- Read the README.md file to better understand the intentions of this package, and how users should expect to use it.
- Reference: See also ADR-0001 (`docs/round_8/adr/adr-0001-toolflow-per-step-generic-typing.md`) for the architectural decision and rationale behind this refactor. Read this ADR before starting implementation.
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
+ [ ] Review the refactor plan in `/plan/refactor-toolflow-per-step-generic-typing-1.md` and ADR-0001 (`docs/round_8/adr/adr-0001-toolflow-per-step-generic-typing.md`). Assess its feasibility and soundness for the current codebase and requirements.
    - The implementation plan is AI-generated and should be used as guidance, not as strict law. If you identify any unsound or suboptimal instructions, update the plan and ADR as needed before proceeding.

 - [ ] Implement the refactor to enable per-step generic ToolResult typing and type-safe audit execution in the ToolFlow system. Ensure that result storage is type-safe and does not use `List<dynamic>`, and that audits receive the correct typed result for each tool step, following the reviewed and updated plan.

### FINAL REQUIREMENTS
- [ ] Please update all relevant existing tests or create new ones for new functionality before officially completing your work.
- [ ] Ensure any necessary ADR files are generated for core decisions made from the above requests.
    - Also update the `adr_references` and `used_as_resource_in` sections of the relevant ADRs so that we know which ADRs have been used in the future.
- [ ] There should be no linting errors or warnings when you are finished with your work.
    - You can run "dart analyze" to see all the linting errors and warnings.
- [ ] Ensure all completed requests have been committed to the PR Branch before moving beyond this task
- [ ] Add an entry in the docs/adr_appendix.md for each of the ADR files that were created above
