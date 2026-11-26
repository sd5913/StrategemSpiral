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

# Automated AI & QTE Test Suite

The AI playtest and input-driven `W/A/S/D` QTE test runner (`res://ai_test_system/ai_test_runner.tscn`) verifies core combat mechanics, all 4 Ultimate card QTE success/wrong-key-reset/timeout-failure paths via injected `InputEventKey` events, and multi-strategy AI simulations. Test-only AI overlay controls remain strictly disabled during normal gameplay and in all exported builds.

Run the headless test suite and generate JSON/Markdown reports (`gameCode/slay-the-strat/ai_test_system/reports/`):

```bash
godot --headless --path gameCode/slay-the-strat res://ai_test_system/ai_test_runner.tscn -- --games-per-strategy=10 --qte-mode=input --auto-quit
```

*(Optional debug-only live overlay in editor/dev runs: `godot --path gameCode/slay-the-strat -- --ai-overlay`)*

# Visual Concept (initial)
<img width="1024" height="572" alt="concept_fix" src="https://github.com/user-attachments/assets/9b6afb8e-5466-42ad-b9e1-aca8fa7355ae" />
[AI-generated conceptual image. Subject to massive changes. NOT finalized UI or build.]
