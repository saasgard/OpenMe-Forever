# Changelog

## 1.2.0

- The same item in several bag slots is now shown once, with the counts added together, instead of once per slot. The item count at the bottom counts every item.
- List is now the default layout for new installs. If you already use OpenMe, your settings are kept as they are.
- The window now also pops up when you loot more of an item that's already listed.

## 1.1.0

- New options window. Open it with the gear button in the window's title bar, with `/openme options`, or from the game's AddOns options.
- New modern skin: a flat, dark window in the same style as DMme's Dark theme, with item borders coloured by quality. Turn it on in the options or with `/openme modern`. `/openme classic` goes back to the game's window style.
- Right-click an item in the window to hide it until you log out or reload. Every stack of that item is hidden, and the window shows how many items are hidden. `/openme unignore` brings them back.
- `/openme list` shows items as a list with their names. `/openme grid` goes back to the icon grid, and `/openme layout` switches between the two. The choice is saved.
- Compact mode: just the items as small icons in a thin box, with no title bar, buttons or frame art. It starts as a single icon and grows as more items come in. Drag the edge to move it. Turn it on in the options or with `/openme compact`.
- `/openme help` lists the commands.
- The window title now reads "OpenMe".
- Dragging the window during combat no longer causes an error. (The window can't move in combat, because it holds buttons that use items.)
- The window remembers its top-left corner, so it grows to the right and down as items are added.

## 1.0.0

First release.

- A window lists the items in your bags that can be opened, such as clams, boxes and satchels. Click one to open it.
- Items that start a quest you haven't accepted yet are listed first, with a yellow "!" border.
- Open Next opens the first item in the list.
- The window opens when you loot something that can be opened, and closes when the list is empty. `/openme auto` turns this off.
- `/openme` shows or hides the window.
