Read and follow all project instructions in ./AGENTS.md

For software development requests, also read and follow the AI-DLC workflow defined in `ai-dlc/aidlc-rules/aws-aidlc-rules/core-workflow.md`. Rule detail files are at `.aidlc-rule-details/`.

## Model Selection

This project uses a two-model strategy to balance quality and cost:

- **Opus** — use for Inception phase (Requirements through Application Design)
- **Sonnet** — use for Construction phase (Functional Design onward)

At the start of each session, state which phase you are in and which model the user should be using. At the transition from Inception to Construction, remind the human to switch the model to Sonnet
before proceeding.