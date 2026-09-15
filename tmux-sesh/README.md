# Sesh Provider for Noctalia

A Noctalia launcher provider for [Sesh](https://github.com/joshmedeski/sesh), the smart tmux session manager.

Type `/ts` in the Noctalia launcher to search Sesh's live tmux sessions, configured sessions, tmuxinator configurations, and zoxide projects.

## Requirements

- Noctalia v5 with support for plugin API 3 or newer
- [`sesh`](https://github.com/joshmedeski/sesh)
- A tmux-compatible multiplexer (tmux by default, as configured in Sesh)

Focusing an existing window additionally uses `tmux`, `hyprctl`, and `ps`, and
requires the session to be attached in Ghostty on Hyprland. The manifest declares
`sesh` and `tmux` as dependencies.

## Installation

From the root of this checkout, copy the plugin into Noctalia's local plugin directory:

```sh
mkdir -p "${XDG_DATA_HOME:-$HOME/.local/share}/noctalia/plugins/tmux-sesh"
cp -R tmux-sesh/. "${XDG_DATA_HOME:-$HOME/.local/share}/noctalia/plugins/tmux-sesh/"
```

Enable **Sesh Provider** in Noctalia's plugin settings. Reload Noctalia's
configuration if the new plugin is not listed yet.

## Usage

1. Open the Noctalia launcher.
2. Type `/ts`, optionally followed by part of a session or project name.
3. Select a result:
   - If that session is already attached in a Ghostty window, the plugin focuses that window through Hyprland.
   - Otherwise, it opens a new terminal and runs `sesh connect` for the selection.

The provider delegates discovery and connection to Sesh, so its `sesh.toml`
configuration, blacklist, and configured multiplexer are respected. An empty query
preserves Sesh's source ordering; a search fuzzy-matches names and paths and ranks
matches by score. Duplicate names are shown once. If no matching Ghostty window
can be focused, the provider opens a new terminal.

Noctalia adds its common command prefix (`/` by default) to `ts`; use your
configured prefix if different.

### Mise

Noctalia may not inherit the `PATH` configured by your interactive shell. If Sesh is installed with Mise and the provider reports that it cannot find `sesh`, set **Sesh command** in the plugin settings to:

```
~/.local/share/mise/shims/sesh
```
