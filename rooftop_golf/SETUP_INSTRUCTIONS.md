# Level Setup Instructions

## Quick Fix for "No Input" Issue

Your level scenes need to have the `game_mode.gd` script attached to work properly.

### For Each Level Scene:

1. Open the level scene in Godot (e.g., `level_1-1.tscn`, `level_1-2.tscn`, etc.)
2. Click on the **root node** (top node in the scene tree)
3. In the Inspector panel, find the "Script" section at the top
4. Click the folder icon next to "Script"
5. Navigate to `res://scripts/game_mode.gd`
6. Click "Open"
7. **Save the scene** (Ctrl+S)

### Verify It Works:

You should see:
- The script icon next to the root node name
- When you run the game, console shows: `"game_mode._ready() called - Input enabled"`
- You can click/drag to aim after the level loads

### Required Scene Structure:

Each level should have this structure:
```
level_X-Y (Node2D) ← game_mode.gd MUST be attached here
├── player (building with spawn_marker)
├── ball (CharacterBody2D)
├── goal (goal scene)
├── aim_line (Line2D)
├── level_manager (optional, but recommended)
├── kill_zone(s) (Area2D)
└── background/parallax elements
```

### Alternative: Create a Base Level Template

1. **Create `level_base.tscn`:**
   - New Scene → Node2D (name it "level_base")
   - Attach `game_mode.gd` to root node
   - Add Camera2D
   - Save as `level_base.tscn`

2. **For each new level:**
   - Scene → New Inherited Scene
   - Select `level_base.tscn`
   - Add your level-specific content (buildings, goal, etc.)
   - Save as `level_1-1.tscn`, `level_1-2.tscn`, etc.

This way, game_mode.gd is automatically included in every level!

### Checklist for Each Level:

- [ ] Root node has `game_mode.gd` script attached
- [ ] Has a node named "player" with "spawn_marker" child
- [ ] Has "ball" CharacterBody2D
- [ ] Has "goal" node
- [ ] Has "aim_line" Line2D
- [ ] Has "level_manager" (optional)
- [ ] Has kill zones for boundaries
- [ ] File named correctly: `level_X-Y.tscn` (e.g., `level_1-1.tscn`)

### Testing:

Run the game and check the console:
- Should see: `"game_mode._ready() called - Input enabled"`
- Should see: `"Ball found at: (x, y)"`
- Click and drag should show debug messages: `"Mouse button event detected..."`
- Release should show: `"Shot fired"`

If you don't see these messages, the script isn't attached properly.
