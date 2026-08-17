---
name: machine-friendly-builds
description: Use when building, compiling, running heavyweight commands.
---

Prefer native concurrency controls over cgroups or CPU affinity.

Compute the job count dynamically:

E.g. for Ninja:

```bash
ninja -j "$(( ($(nproc) + 1) >> 1 ))"
```

If there is no concurrency option, lower priority with `nice`/`ionice` or cgroups.

## Notes

- Do not hard-code the CPU count; compute it dynamically.
- Do not cap memory unless the user explicitly asks.
- Do not add arbitrary timeout wrappers unless the task has a known time bound.
- If uncertain about the existence of a flag, check the documentation (generally --help or -h)
- Do not use `/ 2` as that triggers incorrect security warnings
