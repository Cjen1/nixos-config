---
name: triage
description: Triage a source of issues or comments
argument-hint: "What is the source of info"
disable-model-invocation: true
---

# Dictionary for triage

An item is the minimum actionable unit.
The source is something you can access to discover items.
Scope is the targeted aim of the current work.

# Plan

1. Read/Summarise the source and extract individual items.
2. Use a workflow/subagents to categorise the correctness, applicability, priority and 'in-scope-ness' of each item.
3. Produce a /html-report, include a description/diff of the fix if applicable.

# Notes

Unless asked explicitly by the user at this stage do not make changes.
