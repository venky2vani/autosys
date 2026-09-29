---
name: code-review-checklist
description: Use when reviewing a change. Walks through correctness, tests, error handling and readability.
---
# Code review checklist
1. Does the change do what the description says? Check edge cases.
2. Are there tests covering new behavior and failure paths?
3. Are errors handled or surfaced, never silently swallowed?
4. Is the code readable and consistent with surrounding style?
5. Any security concerns (input validation, secrets, injection)?
