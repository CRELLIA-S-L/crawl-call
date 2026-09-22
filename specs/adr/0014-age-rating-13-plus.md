# ADR-0014 — The target age rating is 13+, and the content filter is set to it

- **Status:** accepted
- **Date:** 2026-09-21
- **Related requirements:** CON-PUB-080, FR-CMD-160

## Context and problem statement

Bot speech is generated at run time, which the App Store treats as user-generated content (guideline 1.2, concept §14).
The filter FR-CMD-160 asks for has to reject *something*, and what it rejects follows from the rating the game aims at (Q-110).

## Considered options

Apple's tiers, per App Store Connect's age-rating reference read on 2026-09-21: 4+, 9+, 13+, 16+, 18+.
9+ admits infrequent cartoon violence and infrequent crude humour; 13+ admits both frequently; 16+ and 18+ admit realistic violence and mature themes the game does not have.

## Decision outcome

**13+.**
The game is cartoon violence for the whole match — soldiers swallowed whole, boots sticking out — which is "frequent", not "infrequent", so 9+ is out on the violence descriptor alone.
The bots' bickering, accusations and panic are insult-based humour, which 13+ admits and 9+ does not; filtering the lines down to 9+ would cut the material the game sells on (I-010).
Nothing in the concept needs 16+, and a higher rating shrinks the audience for no gain.

The filter therefore rejects: derogatory slurs against any group; sexual content; references to real people, organisations, nations or conflicts; threats or instructions of real-world harm.
It admits profanity and crude humour of the kind the descriptor names.

### Consequences

CON-PUB-080 names the rating; FR-CMD-160's filter is configured to this list.
The rating is declared in App Store Connect with the "Cartoon or Fantasy Violence: frequent" and "Profanity or Crude Humor: frequent" descriptors and the "User-Generated Content" capability.
If the model's lines turn out to exceed 13+ often enough to feel censored, the lever is the prompt, not the rating.
