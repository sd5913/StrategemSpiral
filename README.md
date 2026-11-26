# StrategemSpiral

Platform: PC\
Development tool: godot\
Art direction: pixelated\
\
CREDITS:\
GodotGameLab (tutorial videos for what the game is based on)\
Kenny https://kenney.nl/assets/tiny-dungeon (for some of the placeholder pixel art assets and font)



# Initial concept/plan
Player Target: any gamer who wants to try card-based combat but also are open to innovation and merging of genres\
User input: utilizing WSAD to input combos and cast special actions known as ultimates\
System response: Positive when good combos are executed, and if enemy weakness is exploited, players loose bonus or take self damage if they mess up, loose attack oppurtunities if they run out of time, players loose/win in a dps check and tactical game against the enemy NPCs.\
Innovation: speeds up typical turn-based combat to both mechanical skill and on-the-fly thinking.\
First interaction to test: input system logic

# Visual Concept (initial)
<img width="1024" height="572" alt="concept_fix" src="https://github.com/user-attachments/assets/9b6afb8e-5466-42ad-b9e1-aca8fa7355ae" />
[AI-generated conceptual image. Subject to massive changes. NOT finalized UI or build.]



## Automated tests

On Linux, run `bash .codex/test.sh` with Godot 4.7.2 on `PATH`. Set `GODOT_BIN`
to use a specific executable. The runner installs the pinned GUT add-on, imports
the project, and runs the GDScript unit and battle-scene tests headlessly.

The CI workflow also supplies two inputs for release checks:

- `STRATEGEM_LINUX_EXPORT` is the absolute path to the Linux executable.
- `STRATEGEM_RELEASE_METADATA` is the absolute path to the output of
  `gh release view --json tagName,body,assets`.

Both are optional locally. GUT marks the corresponding checks pending when an
input is absent. The suite exits with code 1 when an assertion fails.


