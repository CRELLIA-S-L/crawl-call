#!/usr/bin/env python3
"""Reads a spike CSV (and its console log) and prints the checks' verdicts.

Thresholds are those of spike/README.md: 60 fps by vsync, a frame budget of
16.6 ms with a 20 % margin on the iPhone 16 Pro (13.3 ms), a commander answer
within its 7 s interval, no dropped frames worth mentioning over the run.
Standard library only, as every tool in this repository.
"""
import csv
import re
import sys

CPU_BUDGET_MS = 16.6 * 0.8      # CPU work per frame: the iPhone 16 Pro margin against the 15 Pro baseline (ADR-0015)
DROPPED_INTERVAL_MS = 1000 / 60 * 1.5   # a display interval this long means a frame was missed
COMMANDER_INTERVAL_MS = 7000


def load(path):
    with open(path, newline="") as f:
        rows = list(csv.DictReader(f))
    for r in rows:
        for k, v in r.items():
            if k != "thermal":
                r[k] = float(v)
    return rows


def main(csv_path, log_path=None):
    rows = load(csv_path)
    if not rows:
        print("empty csv"); return 2
    n = len(rows)
    vs = [r["vsync_fps"] for r in rows]
    dropped = sum(r["vsync_dropped"] for r in rows)
    vmax = max(r["vsync_max_ms"] for r in rows)
    delib_avg = sum(r["delib_avg_ms"] for r in rows) / n
    delib_max = max(r["delib_max_ms"] for r in rows)
    path_max = max(r["path_max_ms"] for r in rows)
    req = sum(r["path_requests"] for r in rows) / n
    fails = sum(r["path_failures"] for r in rows)
    infer_rows = [r for r in rows if r["infer_max_ms"] > 0]
    infer_max = max((r["infer_max_ms"] for r in rows), default=0)
    # The first ten seconds are the model's warm-up (loading), which the game does on its loading screen.
    play = [r for r in rows if r["t"] > 10]
    infer_frame_max = max((r["infer_frame_max_ms"] for r in play), default=0)
    dropped_play = sum(r["vsync_dropped"] for r in play)
    warm_dropped = dropped - dropped_play
    thermal = []
    for r in rows:
        if not thermal or thermal[-1][1] != r["thermal"]:
            thermal.append((int(r["t"]), r["thermal"]))
    first_min = [r for r in rows if r["t"] <= 60]
    last_min = rows[-60:]
    fps_first = sum(r["vsync_fps"] for r in first_min) / max(1, len(first_min))
    fps_last = sum(r["vsync_fps"] for r in last_min) / max(1, len(last_min))

    calls = []
    if log_path:
        try:
            for line in open(log_path, encoding="utf-8", errors="replace"):
                m = re.search(r"\] (warmup|call) (\d+) ms in (\d+) tok \(cached (\d+)\) out (\d+)", line)
                if m:
                    calls.append((m.group(1), int(m.group(2)), int(m.group(3)), int(m.group(4)), int(m.group(5))))
                elif "context exceeded" in line or "failed after" in line:
                    calls.append(("fail", 0, 0, 0, 0))
        except OSError:
            pass
    work = [c for c in calls if c[0] == "call"]
    failures = sum(1 for c in calls if c[0] == "fail")

    print(f"run: {n} s, thermal timeline: " + " → ".join(f"{t}s {s}" for t, s in thermal))
    print(f"vsync fps min/avg {min(vs):.1f}/{sum(vs)/n:.1f}, first minute {fps_first:.1f}, last minute {fps_last:.1f}; "
          f"worst interval {vmax:.1f} ms; dropped {int(dropped)} of ~{n*60} ({int(warm_dropped)} in the first 10 s)")
    print(f"deliberation avg {delib_avg:.3f} ms, worst frame {delib_max:.2f} ms; path requests {req:.0f}/s, "
          f"failures {int(fails)}, slowest path {path_max:.2f} ms")
    if work:
        lat = [c[1] for c in work]
        cached = [c[3] for c in work]
        print(f"commander: {len(work)} calls, latency avg {sum(lat)/len(lat):.0f} ms max {max(lat)} ms, "
              f"input tokens {min(c[2] for c in work)}–{max(c[2] for c in work)}, cached tokens avg {sum(cached)/len(cached):.0f}, "
              f"failures {failures}; worst display interval during inference {infer_frame_max:.1f} ms")
    else:
        print(f"commander: no calls parsed from the log (infer max in csv {infer_max:.0f} ms)")

    print()
    verdict = []
    verdict.append(("check 2: 60 fps, ≤ %d dropped frames after warm-up" % max(3, n // 100),
                    sum(vs) / n >= 59.5 and dropped_play <= max(3, n // 100)))
    verdict.append(("check 2: deliberation worst frame ≤ %.1f ms" % CPU_BUDGET_MS, delib_max <= CPU_BUDGET_MS))
    if work:
        verdict.append(("check 3: no frame missed during inference after warm-up (interval ≤ %.1f ms)" % DROPPED_INTERVAL_MS,
                        infer_frame_max <= DROPPED_INTERVAL_MS))
        verdict.append(("check 3: commander latency < %d ms" % COMMANDER_INTERVAL_MS, max(lat) < COMMANDER_INTERVAL_MS))
        verdict.append(("check 3: no failed calls", failures == 0))
    if n >= 15 * 60:
        verdict.append(("check 3: last minute ≥ 60 fps after %d min" % (n // 60), fps_last >= 59.5))
        verdict.append(("check 3: thermal never 'serious' or 'critical'", all(s not in ("serious", "critical") for _, s in thermal)))
    else:
        verdict.append((f"check 3: thermal run ≥ 15 min (this run: {n // 60} min)", False))
    for name, ok in verdict:
        print(("PASS  " if ok else "FAIL  ") + name)
    return 0 if all(ok for _, ok in verdict) else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None))
