# Invariants and constraints

`INV-*` — properties that hold at all times, phrased with **shall** / **shall not**.
`CON-*` — externally imposed constraints: platform limits, legal requirements, protocol versions.

Source: concept §5 (abilities never shoot), §7 (what never breaks), §6 (what scores), §8 (shared archetypes), §9.3 (execution every frame), §10 (platform), §11 (what is not copied), §17 (licensing, identifiers, App Store).
Frames of the grounds register — F-010, F-020, F-030 — are the boundaries these invariants and constraints enforce inside the specification; the register says why they will not move, the requirements say what holds.

## Invariants

### INV-SNAKE-010 — No ability shoots

```yaml
status: deferred
verification: I
derives_from: []
depends_on: [FR-SNAKE-110]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

The system **shall not** give the snake any ability, upgrade or item that deals damage to a bot at a distance.

**Rationale.** Concept §5: the moment the snake has firepower the asymmetry collapses, and in the boring direction.
Destruction of geometry is not an exception to this sentence — it damages modules, not bots.
Frame F-010.

### INV-SNAKE-020 — The snake is slower than a running bot

```yaml
status: deferred
verification: T
derives_from: []
depends_on: [FR-SNAKE-030]
refines: []
conflicts_with: []
code: []
tests: [Tests/CrawlCallTests/ConfigurationTests.swift]
created: 2026-09-21
```

The snake's base speed in the snake configuration **shall** be lower than the run speed of every archetype in the bot configuration.

**Rationale.** Concept §1: the snake is slow, the bots are fast — the asymmetry.
The dash (FR-SNAKE-130) is the temporary exception the player earns by eating an assault.

### INV-BOT-010 — Execution runs every frame for every bot

```yaml
status: implemented
verification: T
derives_from: []
depends_on: [FR-BOT-150]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Execution.swift, Sources/CrawlCall/Game.swift]
tests: [Tests/CrawlCallTests/ExecutionTests.swift]
created: 2026-09-21
```

In every frame, the system **shall** update aim, movement, animation and collision for every living bot, whatever the deliberation rate.

**Rationale.** Concept §9.3: cut execution to 7 Hz and aim steps, movement jerks; a delayed decision goes unnoticed, jerky motion is seen at once.

### INV-BOT-020 — Squads never remove bodies

```yaml
status: deferred
verification: T
derives_from: []
depends_on: [FR-SCORE-110]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

The system **shall not** let a bot move, carry or remove a body.

**Rationale.** Concept §6.2: the snake consumes bodies, squads do not — a vanished body is therefore only ever the snake's doing, and the whole awareness mechanism rests on that.

### INV-BOT-030 — Both squads share one archetype set

```yaml
status: implemented
verification: I
derives_from: []
depends_on: [FR-BOT-010, FR-BOT-020]
refines: []
conflicts_with: []
code: [Sources/CrawlCall/Bot/Archetype.swift, Sources/CrawlCall/Bot/Squads.swift]
tests: [Tests/CrawlCallTests/BotTests.swift]
created: 2026-09-21
```

The two squads **shall** differ only in colour and in their commander, never in the set of archetypes available to them.

**Rationale.** Concept §8: the player learns six silhouettes, not twelve; asymmetry, if wanted, comes from the proportions of a squad, not from unique classes.

### INV-SCORE-010 — Nothing but consumption scores

```yaml
status: deferred
verification: T
derives_from: []
depends_on: [FR-SCORE-010]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

The system **shall not** change the score on any event other than the snake finishing a consumption.

**Rationale.** Concept §6: a bot killed by the enemy squad brings the snake nothing by itself; specific trick bonuses were rejected because they get farmed (ADR-0006).
Watching is useful, doing nothing is not.

### INV-SCORE-020 — A body stays until the snake consumes it

```yaml
status: deferred
verification: T
derives_from: []
depends_on: [FR-SCORE-110, INV-BOT-020]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

The system **shall not** remove a body from the map by any means other than the snake consuming it.

**Rationale.** ADR-0013: decay would make a rotted body look, to FR-SCORE-125, like one the snake ate, and would let evidence fade; a body is map state for the whole match.
INV-BOT-020 says squads do not move bodies; this says nothing else does either.

### INV-MAP-010 — The load-bearing frame never breaks

```yaml
status: deferred
verification: T
derives_from: []
depends_on: [FR-MAP-060]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

The system **shall not** change the state of a module declared load-bearing, whatever the source of damage — bot weapon, snake body or sapper ability.

**Rationale.** Concept §7: walls, stairs and floor slabs never break, or the navigation graph falls apart and with it the verticality that is the reason the map is multi-level.

### INV-MAP-020 — Destruction never disconnects floors

```yaml
status: deferred
verification: T
derives_from: [INV-MAP-010]
depends_on: [FR-MAP-050]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

After any change of a module's state, every floor of the map **shall** remain reachable from every other floor over the navigation graph.

**Rationale.** Concept §7: destructible is everything that can be removed without changing the connectivity between floors.
Stated separately from INV-MAP-010 because it is the property, and INV-MAP-010 the mechanism meant to guarantee it; a kit that declared a stair destructible would pass one and fail the other.

## Constraints

### CON-PUB-010 — Platforms

```yaml
status: deferred
verification: I
derives_from: []
depends_on: []
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

The game **shall** target iOS 27, iPadOS 27 and macOS 27 or later on devices that support Apple Intelligence — iPhone 15 Pro and later, the iPads that support it, Apple silicon Macs — from one code base.

**Rationale.** Concept preamble and §10: iOS 27+ / macOS 27+, one build for every Apple platform; iPhone is the primary target, the Mac the development environment (concept §15).
iPadOS joined on 2026-09-24 by the maintainer's decision, which closed Q-210: the overview had named it from the start and the constraint had not.
Older devices are out, knowingly; the line sits at the iPhone 15 Pro rather than at iOS 27's own floor because the system language model is not available below it (ADR-0015).

### CON-PUB-020 — Source under the MIT licence

```yaml
status: deferred
verification: I
derives_from: []
depends_on: []
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

The repository's own code, specification and assets **shall** be published under the MIT licence with the company as copyright holder.

**Rationale.** Concept §17.2: the same licence as SRS-DD, one policy for the company; GPL rejected because contributors' GPL code cannot ship in the App Store without their consent (ADR-0007).
Closed clones are permitted and that is accepted knowingly (§17.3).

### CON-PUB-030 — Third-party assets keep their licences

```yaml
status: deferred
verification: I
derives_from: [CON-PUB-020]
depends_on: []
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

Every third-party asset in the repository **shall** be listed in the attribution file with its source and a licence that permits commercial redistribution.

**Rationale.** Concept §17.2: kits like Kenney or Quaternius keep their own licences, recorded in the attributions file.
The listing and the licence it lists are one act of admitting an asset; an asset whose licence does not permit redistribution is not admitted.

### CON-PUB-040 — Signing identifiers stay out of the repository

```yaml
status: deferred
verification: I
derives_from: [CON-PUB-060]
depends_on: []
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

The repository **shall** carry the bundle identifier and development team only as placeholders in `Signing.example.xcconfig`, the real values living in a `Signing.xcconfig` that is ignored by git.

**Rationale.** Concept §17.4: the bundle ID is public but the repository ships a placeholder of the form `com.example.chompcompany`; the Team ID belongs to the company; forks need their own bundle ID anyway.

### CON-PUB-050 — No Team ID in the project file

```yaml
status: deferred
verification: T
derives_from: [CON-PUB-040]
depends_on: []
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

The Xcode project file **shall not** contain a development team identifier.

**Rationale.** Concept §17.4: the Xcode trap — picking a team writes the Team ID into `project.pbxproj` behind the config's back.
Enforced by FR-TOOL-140.

### CON-PUB-060 — No secrets in the repository or its history

```yaml
status: deferred
verification: I
derives_from: []
depends_on: []
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

Before the repository is made public, its full history **shall** have been scanned for certificates, private keys, App Store Connect keys and provisioning profiles, and found clean.

**Rationale.** Concept §17.4: deletion in the last commit does not help — the file stays in history; if a secret got in, the history is rewritten and the key reissued.
A scanner such as gitleaks is the concept's example; the requirement is the clean result.

### CON-PUB-070 — Nothing from another game is named

```yaml
status: deferred
verification: I
derives_from: []
depends_on: []
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

The store listing, the devlog, the pitch and the game itself **shall not** name any existing game franchise, map or studio.

**Rationale.** Concept §11: the names of specific maps and franchises appear nowhere — not in the store, not in the devlog, not in the pitch; §17.6 rejected "Call of Chomp" on exactly this ground.
Frame F-020.

### CON-PUB-080 — Generated speech is treated as user-generated content

```yaml
status: deferred
verification: I
derives_from: []
depends_on: [FR-CMD-140]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

The game **shall** be submitted at the 13+ age rating with the user-generated-content capability declared, every generated line having passed the content filter before display.

**Rationale.** Concept §14: the App Store treats real-time generated content as user-generated.
The filter is FR-CMD-160; the rating and what the filter rejects are ADR-0014.

### CON-PUB-090 — The name stays inside the repository until the search clears it

```yaml
status: deferred
verification: I
derives_from: [CON-PUB-070]
depends_on: []
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

The name "Crawl Call: Chomp Company" **shall** appear only in the repository, code, documentation and identifiers until a professional trademark search in classes 9 and 41 has cleared it.

**Rationale.** The maintainer settled the name on 2026-09-22, ahead of the search rather than after it, so what this constrains is no longer a working title but the intended one.
The reason to hold it back is unchanged: concept §17.6 records that "Chomp" is taken in apps — a children's app, a Google Play game and a UK studio — and a name spoken publicly before a search in classes 9 and 41 is a name that cannot be quietly changed afterwards.
"Crawl Call" is the half the search has to clear first, since it carries the mark; the subtitle rides with it (Q-120).

### CON-MAP-010 — No existing map is reproduced

```yaml
status: deferred
verification: I
derives_from: [CON-PUB-070]
depends_on: [FR-MAP-100]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

No map **shall** reproduce the layout, silhouette or landmarks of a map from an existing game, whether redrawn or assembled from modules.

**Rationale.** Concept §11: the layout is what is protected, not the material it is built from; fan remakes fell on recognisability, not on stolen files.
The practical test: could a player with a hundred hours in the original name the map?
Frame F-020.

### CON-PUB-100 — Commit authorship exposes no personal address

```yaml
status: deferred
verification: I
derives_from: [CON-PUB-060]
depends_on: []
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

Before the repository is made public, every commit in its history **shall** carry a company or no-reply author address.

**Rationale.** Concept §17.4: check the email in commits; use an anonymous no-reply address where needed.
The history is rewritten once, before publication, rather than policed afterwards.

### CON-PUB-110 — The company is the seller

```yaml
status: deferred
verification: I
derives_from: [CON-PUB-020]
depends_on: []
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-21
```

The App Store listing **shall** name the company as seller and trader, with the company's business contact details.

**Rationale.** Concept §17.5: under the Digital Services Act Apple shows a paid app's trader details publicly; for a company those are business details, not the developer's home address.
Registering as an organisation needs a D-U-N-S number, which takes time and is started early; the Team ID then belongs to the company.

### CON-PUB-120 — Xcode 27 is the minimum toolchain

```yaml
status: deferred
verification: I
derives_from: [CON-PUB-010]
depends_on: []
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-22
```

The project **shall** build with Xcode 27 and the iOS 27 / macOS 27 SDK, using nothing a newer Xcode alone provides.

**Rationale.** The maintainer's decision of 2026-09-22: development is done in Xcode 27 and that version is the minimum supported one, so a contributor with Xcode 27 can always build.
The concept named "Xcode 18" from independent sources without verification; the SDK the engine decision needs (ADR-0001) ships with Xcode 27.

### CON-CMD-010 — The system language model's context and cache

```yaml
status: deferred
verification: A
derives_from: []
depends_on: [NFR-PERF-080]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-22
```

Every call to the system language model **shall** fit its instructions, transcript and prompt within the model's context window of 4096 tokens.

**Rationale.** Measured in the spike on iOS 27.0 (`materials/spike/README.md`): the context is 4096 tokens; a `LanguageModelSession` keeps every exchange, so a session called every 7 s with a ~540-token exchange overflows on the seventh call; the model's prefix cache belongs to the session object — a rebuilt session starts uncached — and is evicted above roughly 3000 tokens of transcript; an uncached prefill of 1.6–3.3 k tokens dropped 9–25 display frames, one of ~600 tokens dropped none.
FR-CMD-025 says how the commander lives within this.

### CON-CMD-020 — The model refuses a share of calls

```yaml
status: deferred
verification: A
derives_from: [CON-CMD-010]
depends_on: [FR-CMD-140]
refines: []
conflicts_with: []
code: []
tests: []
created: 2026-09-22
```

The game **shall** keep working, with no voice missing and no order lost, when up to one call in five is refused.

**Rationale.** Measured in the spike on iOS 27.0 (`materials/spike/README.md`, ADR-0017).
The rate is a property of the wording, not a constant: the same hundred-call bench gave 10 blocked with the game's first instructions and 0 with the measured ones, and every block fell on the one situation whose state was written as wounds and bodies.
`permissiveContentTransformations` does not apply — the documentation states that guided generation runs the default guardrails whatever the mode says.
The subject — soldiers being swallowed — is what the model objects to, so the rate is a property of the game, not of a prompt to be fixed.
One in five is the bound the game is built to survive, well above anything measured; FR-CMD-165 is how.
The bound is kept generous on purpose: Apple ships new models with OS updates and asks that every prompt test be re-run against them, so the rate this project measured is a reading of one model version.
