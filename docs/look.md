# Theme and colors

Scope: change the theme of Herdr and its accent color, from the command palette or with a command.

herdspace sets the Herdr theme `dracula`, with its own colors for the agent states. The accent color is the color of the headers and the highlights of Herdr. By default, it is the color of the theme.

## Change the theme

1. Open the command palette: `Cmd+Shift+P` on a Mac, `Ctrl+Shift+P` on Linux.
2. Choose "herdspace: Change the Herdr theme". The right side of the row shows the current theme.
3. Choose a theme in the list. Each theme has a sample of its background and its accent. "Random" chooses a theme that is not the current one.

The theme changes at once in each running session. You can also run the command:

```bash
herdspace theme nord
```

`herdspace theme` with no name shows the current theme and the list. `herdspace theme random` chooses a theme for you. `herdspace theme default` goes back to `dracula`.

## Change the accent color

1. Open the command palette.
2. Choose "herdspace: Change the Herdr accent color". The right side of the row shows the current color.
3. Choose a color in the list. Each color has a sample. "Random" chooses a color that is not the current one, and "Default" uses the color of the theme again.

You can also run the command, with a name of the list or a `#rrggbb` value:

```bash
herdspace color pink
```

The colors of the list are red, orange, yellow, green, teal, cyan, blue, purple, and pink. `herdspace color` with no color shows the current color. `herdspace color random` chooses one for you, and `herdspace color default` uses the color of the theme.

## What stays after an update

Each choice is in a file of `~/.config/herdspace/`: `theme` and `accent`. The setup writes the saved choices into `~/.config/herdr/config.toml`, so an update of herdspace keeps them and asks no question about the file. The [prefix key](keyboard-shortcuts.md#the-prefix-key) works the same way. `herdspace uninstall` removes the files.

The popups of `hopen`, such as the palette and quick open, keep the herdspace colors with each theme.
