Read and follow all project instructions in ./AGENTS.md

For software development requests, also read and follow the AI-DLC workflow defined in `ai-dlc/aidlc-rules/aws-aidlc-rules/core-workflow.md`. Rule detail files are at `.aidlc-rule-details/`.

## Knowledge Vault

A pre-analyzed knowledge vault lives at `~/Documents/ai-dlc-vault` and is accessible via the `obsidian-mcp` MCP server. Always use the MCP tools (`read_note`, `search_notes`, `search_by_tag`) to interact with the vault — never read vault files directly from the filesystem. This ensures correct path resolution and consistent access across sessions.

## Model Selection

This project uses a two-model strategy to balance quality and cost:

- **Opus** — use for Inception phase (Requirements through Application Design)
- **Sonnet** — use for Construction phase (Functional Design onward)

At the start of each session, state which phase you are in and which model the user should be using. At the transition from Inception to Construction, remind the human to switch the model to Sonnet
before proceeding.
