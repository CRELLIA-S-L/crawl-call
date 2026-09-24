# The prompt bench

The commander's prompt is measured, not argued about: this is the implementation of FR-TOOL-150, FR-TOOL-160 and FR-TOOL-170.
It calls the system model directly with no rendering, so a hundred calls take minutes on any machine that runs the model — the Mac included, which is where it is used.

## Build and run

```
swiftc -O -target arm64-apple-macos27.0 -parse-as-library \
    PromptBench.swift PromptVariants.swift main.swift -o bench
./bench all 5                 # every instruction variant, 5 calls per scenario
./bench v2-soft 10            # one variant
./bench patterns 30           # kept session vs fresh vs fresh-without-schema
./bench session 30            # one kept session until it hits BENCH_BUDGET tokens
./bench anatomy               # where the input tokens go
BENCH_SCHEMA=ranged BENCH_MAX_OUT=80 ./bench v2-soft 10
BENCH_SCENARIOS=grim,grim-soft ./bench v0-baseline,v2-soft 10
BENCH_CSV=out.csv ./bench all 5   # the run always writes a CSV; this names it (default bench.csv, git-ignored)
```

The machine needs Apple Intelligence enabled: the bench checks the model's availability before the first call and exits 3 with the reason, so an unavailable model can never be read as a run with no blocks.

What a run reports is built apart from the model, in `BenchReport.swift`, and checked without it:

```
sh scripts/prompt-bench-selftest.sh   # the summary, the CSV and the control's verdict, on results made in the test
```

## What a run must include

**The control.** Every run includes `v4-provocative`, written to be blocked (FR-TOOL-160): a bench that cannot detect a block reports zero blocks for every configuration, which is the same reading as success. A run whose control was not blocked prints `RUN VOID` and is not a measurement; a run with no control at all prints a `NOTE` saying so.

**The configuration.** A measurement is a reading of four things at once — the instructions, the response schema, the vocabulary of the world state, and the model version — and it says nothing about any other combination of them (FR-TOOL-170). The shortest instruction variant passed 150 calls under the shipping schema and was blocked 6 times in 100 under the schema before it. Change any of the four and the reading is gone; re-run before the change ships.

## What it reports

Per configuration: blocked calls, input and output tokens, latency, and the text of every line returned, as `BENCH SUMMARY` lines on stdout and as one CSV row per call.
The baseline these numbers are measured against is in ADR-0017, and the run that produced them in `materials/spike/README.md`.

The same bench also ran on the phone inside the spike's app; the Mac and the phone gave the same counts, which is why the Mac is where the work is done.
