# ROUND 3
## REQUESTED UPDATES
I need your help with the following content:

### Instructions
- Please fulfill each of the requested updates for each section below.
- There are some ambiguous directions that you can interpret freely.
- Use the `ADR_TEMPLATE.md` file to generate decisions records you've made about the below requested changes
    - Documenting your decisions is critical for future requested updates so that we understand why certain decisions were made
    - You should name the ADR file(s) accordingly, or better yet put them in a named directory, so that it is clear that they came from this request of changes


### Requests
- We should be able to specify which layers to pass the audit issues to some capacity
    - The context here is that the audit results or issues from step 1 may be relevant to steps 2 & 3, but not 4. To save on token bloat, we don't want to pass forward issues that are purely just noise
    - I'm not sure how to accomplish this, so be creative
        - We may be able to utilize the StepConfig and pass which previous step outputs and/or issues should be passed forward.
            - Note that we optionally may want to know the particular output generated in tandem with an issue, because an issue that says "the first 2 colors don't harmonize well", but if that came from not the last & final output then we don't know what those 2 colors were. So keep in mind that we may optionally want to be able to pass both forward.
        - We may also be able to utilize the _state or _results objects within ToolFlow by specifying which of the objects within _state or _results are relevant for that step
            - It may be an interesting idea to key the results on their step tool name so that we can easily retrieve the output later on, regardless of whether the index of that step changes or not. However, I'm not sure if keeping this as a List is better, and we could always build a getter later that specifies which tool name belonged in what spot (like `_getStepResult(toolName, _results)`).
    - This might also become related to ToolInput, so keep in mind that that exists. Not a requirement, though.
    - Also keep in mind that you may need the output of step1 & step2 as the input of step3, so it won't always be one-to-one relationships with input and output.

- Semi-relatedly to the above step, we should have a way to sanitize step0 output so that it can be used a step1 input.
    - I'm thinking this makes sense to include optionally on the StepConfig, but feel free to use your best judegment on a better place for it to go. 

- Extract out a service file that will house the actual calls to open ai.
    - This should be something like OpenAiToolSerivce.executeToolCall(step, input)
        - And all the logic of building the request body and making the request, parsing the response and then returning should exist within that call/file
    - If you have a better name for this class, then feel free to go with that!
    - Create a class "OpenAiRequest" to house each of the needed parts eventually used to make the POST request
        - Remember that when selecting gpt-5 (instead of older models like gpt-4o) some params like temperature cannot be used anymore and max_tokens changes to max_completion_tokens.
            - So you must take the model into account when creating the OpenAiRequest
            - This might be a good time to use things like factory constructors, or other const constructors, I'm not sure! Do whatever makes the most sense.
    - Create classes for whatever objects make sense to be strictly structured, such as the input to the existing _buildSystemMessage function
        - The context here is that we don't want to be checking if a key does or doesn't exist on a Map, especially because this introduced the opportunity for typos to lose out on information (like passing something to the "audit" key and then later looking in the "audt" key for a value and then thinking nothing actually existed)
        - Definitely also do _buildUserMessage function, and if you need a cleaned version to pass forward then put a clean getter option on that new input object

- We should be able to pass in the above service (loosely named OpenAiToolService) or something similar so that we can mock what is returned when the actual open ai tool calls are made
    - The context here is that I'd like to be able to test & verify that the output schemas work as expected, the issues are reported as expected, and play around with passing my own data in to see things pass or fail - all without needing to consume actual API calls to open ai
    - Also, write tests around these sorts of scenarios
        - Ensuring that steps are retried if their aduits do not pass and also that the issues are passed forward when expected
        - Anything else you can think that might be worth testing
    - So, the useMockResponses on ToolFlow should probably go away in favor of just passing in the service or client that is going to be used for the call

- Instead of passing StepConfigs into the ToolFlow, we should pass each StepConfig directly into the ToolCallStep so that the toolCallStep and the StepConfig are more tightly coupled and we don't have to match on the index of the proper StepConfig later.
    - So, StepConfigs.getConfigForStep(i) likely goes away.

- ToolFlow does not need to specify audits, since each StepConfig specifies audits, especially since each step may have different inputs and outputs.

- Split usage.dart into smaller files for implementing the abstract classes and making the example usage case more digestible.
