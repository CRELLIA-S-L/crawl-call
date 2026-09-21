# Verification

How each verification method is carried out in this project.

| Method | Meaning here |
|---|---|
| `T` — test | Automated test in the repository, path listed in the requirement's `tests` field |
| `D` — demonstration | Manual scenario; describe the steps and the expected observation |
| `I` — inspection | Reading the code or configuration confirms conformance |
| `A` — analysis | Reasoning, measurement, or modeling; link the write-up |

Implemented or partially implemented requirements with an empty `tests` field appear in `90-traceability.md` under “Requirements without listed tests”, whatever their method — as a reminder to either add the test or record how the check was performed.

Test files may additionally carry `verifies:` annotations — see the Annotations section of `README.md`.
