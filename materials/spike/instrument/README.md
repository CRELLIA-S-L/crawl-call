# The spike's measurement instrument — kept as a record

These three files drove and read the unattended run that measured the spike: `run-autopilot.sh` built, installed and launched the app on the phone, `Autopilot.swift` steered it along a fixed route with the checks' toggles on a timeline, and `analyze.py` turned the per-second CSV the app left in its Documents folder into the verdicts.

**They do not run any more.** The app they drove was deleted with the rest of the spike, and the paths inside them (`Spike.xcodeproj`, `../Signing.xcconfig`, `spike/run-autopilot.sh` in the usage line) name what is gone or has moved.
They are kept because `specs/50-verification.md` requires every performance and thermal number to come from an unattended run of exactly this shape — a fixed route, telemetry pulled from the device afterwards, reproducible by anyone holding the device — and this is the working example the game's own instrument is built from.

What they enforced and why it matters to the next one:

- the script refuses to run without a device passed in the environment, and takes the bundle prefix from the git-ignored `Signing.xcconfig`, so no identifier reaches the repository (CON-PUB-040, CON-PUB-050, CON-PUB-060);
- it aborts when the launch fails and rejects a CSV older than the run itself — both after a locked phone let a previous run's data be read as this one's;
- `analyze.py` counts a missed frame as a display interval longer than one and a half times a fixed 16.67 ms, never a period taken from the display itself — the run that took its reference from `CADisplayLink.duration` counted 33 frames as dropped that were not, and `specs/50-verification.md` carries the rule that came out of it.
