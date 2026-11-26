# Panes and layout

[Documentation index](README.md) · [Cheat sheet](cheat-sheet.md) · [Words](cheat-sheet.md#words)

Scope: split, swap, resize, zoom, and close panes, templates, and scroll, search, and copy in a pane.

## Panes

The [templates guide](templates.md) has short videos of these keys.

An ordinary pane closes with no question, and its program stops.

| Action | Keys |
|--------|------|
| Split right | `ctrl+b`, `v` |
| Split down | `ctrl+b`, `-` |
| Go to the pane on the left, below, above, or right | `ctrl+b`, `h`, `j`, `k`, `l` |
| Swap the pane with the pane on the left, below, above, or right | `ctrl+b`, `shift+h`, `shift+j`, `shift+k`, `shift+l` |
| Zoom the pane, or return | `ctrl+b`, `z` |
| Resize mode | `ctrl+b`, `r` |
| Rename pane | `ctrl+b`, `shift+p` |
| Close pane | `ctrl+b`, `x` |

## Swap panes

A swap moves the focused pane, with its program, to the place of its neighbor. The neighbor moves to the old place. The programs keep running.

| Action | Keys |
|--------|------|
| Swap with the pane on the left | `ctrl+b`, `shift+h` |
| Swap with the pane below | `ctrl+b`, `shift+j` |
| Swap with the pane above | `ctrl+b`, `shift+k` |
| Swap with the pane on the right | `ctrl+b`, `shift+l` |

## Resize and zoom

Drag the border between two panes with the mouse, or press `ctrl+b`, `r` for the resize mode of Herdr. `ctrl+b`, `z` zooms the focused pane to the whole tab, and the same keys return.

## Split with a program

The command palette opens a program beside the current pane. Press `Ctrl+V` (right), `Ctrl+S` (below), or `Ctrl+T` (new tab) instead of Enter. See [Choose where a program opens](hopen.md#choose-where-a-program-opens). To split the whole tab with a template, run `hopen --apply NAME`. See the [templates guide](templates.md).

## Scroll, search, and copy

| Action | Keys |
|--------|------|
| Copy a mouse selection | Select, then `Ctrl+C` |
| Open copy mode | `ctrl+b`, `[` |
| Move in copy mode | `h`, `j`, `k`, `l`, or `PageUp`, `PageDown` |
| Search in copy mode | `/`, then `n` or `N` |
| Start a selection in copy mode | `v` or `Space` |
| Copy in copy mode | `y` or `Enter` |
| Leave copy mode | `q` or `Esc` |
| Open the scrollback in `$EDITOR` | `ctrl+b`, `e` |

## References

- [Herdr documentation](https://herdr.dev/tui/docs/)
- [Herdr keyboard](https://herdr.dev/tui/docs/keyboard/)
- [Herdr CLI reference](https://herdr.dev/tui/docs/cli-reference/)
