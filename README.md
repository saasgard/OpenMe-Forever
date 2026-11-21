![OpenMe Forever](Media/Art/logo.png)

# OpenMe Forever

A small World of Warcraft addon for the **Forever** client (Interface 16001) that pops up a window listing everything in your bags you can open:

- Containers you can loot: clams, boxes, satchels, sacks (locked lockboxes are skipped)
- Items that start a quest you haven't accepted yet (marked with the yellow **!**)

The window uses the game's own frame style, or a flat dark "modern" skin, and has a bare-bones compact mode. Pick in the options (gear button, or `/openme options`).

Click an item to open it, or press **Open Next** to open the next one. The game only allows one item to be opened per click, so each item takes its own click; the addon can't open everything at once.

## Usage

| Command | What it does |
| --- | --- |
| `/openme` | Show or hide the window |
| `/openme options` | Open the options window (also the gear button in the title bar) |
| `/openme auto` | Turn the automatic pop-up on or off |
| `/openme list` / `/openme grid` | Show items as a list with names (default) or as an icon grid; `/openme layout` toggles |
| `/openme compact` | Turn compact mode on or off: just the items in a thin box, no title bar or buttons (drag the edge to move it) |
| `/openme modern` / `/openme classic` | Flat dark skin (DMme Dark style) or the game's own window style; `/openme skin` toggles |
| `/openme unignore` | Show items you right-clicked away again |
| `/openme help` | List the commands |

The window pops up when something new you can open lands in your bags, and hides itself once the list is empty. Drag it to move it; the position is saved, and the window grows to the right and down from its top-left corner.

The same item in several bag slots is shown once, with the counts added together, like a stack.

Right-click an item to ignore it until you log out or `/reload`. All stacks of that item are hidden, and the item count shows how many are being ignored.

Because opening items needs a real click, the window can't be opened, closed, moved or updated during combat. It catches up as soon as combat ends.

## Files

- `OpenMe Forever.toc`, `OpenMe.lua`: the addon
- `Options.lua`: the options window
- `Media/Icon.tga`: 64×64 in-game icon (addon list and window portrait)
- `Media/gear.tga`: the options button (white, tinted in code; same as DMme's)
- `Media/Art/logo.png`: 1280×640 banner for the top of a project description
- `Media/Art/curseforge_avatar_400.png`: 400×400 PNG project avatar (CurseForge requires 400×400 and advises against WebP)
- `Media/Art/icon_512.png`, `icon_64.png`: the icon at high and in-game resolution
- `Tools/make_art.py`: regenerates the art (`python Tools/make_art.py Media/Art`, needs Pillow)

## Author

Made by **Skeide**.
