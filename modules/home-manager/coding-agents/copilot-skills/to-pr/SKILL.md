---
name: to-pr
description: Use when the user wants to open a PR.
---

This skill describes how to open a PR in a style which is easy for reviewers to review
This means that the PR text should be 'stateless' in that this conversational context is not required to understand the title or description.
Overall text should be consise and to-the-point.

# PR sections

## Title

This will become the commit message.
So it should describe the high-level aim of the PR.

eg:
- Improve the performance of <subsystem>
- Add Windows CNG crypto provider

## Description

The overall format should be:
- Sentence expanding on the title
- ? paragraph of context
- ? any discontinuities from standards of the codebase to draw reviewers attention to
- ? manual testing if any

? sections can be omitted

# Checklist

- Title and description match existing
- If the repo has a CHANGELOG.md and this PR addresses public facing APIs or behaviour, add a changelog entry.
  - format: <description/title> (<pr number>)
  - Target audience is end-users who wish to know what changed with the system
