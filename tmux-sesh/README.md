# Sesh Provider for Noctalia

A Noctalia launcher provider for [Sesh](https://github.com/joshmedeski/sesh), the smart tmux session manager.

Type `/ts` in the Noctalia launcher to search Sesh's live tmux sessions, configured sessions, tmuxinator configurations, and zoxide projects.

## Requirements

- Noctalia v5.0.0 or later
- [`sesh`](https://github.com/joshmedeski/sesh)
- A tmux-compatible multiplexer (tmux by default, as configured in Sesh)

## Installation

Clone this repository into Noctalia's plugins directory, then enable **Sesh Provider** in Noctalia's plugin settings.

## Usage

1. Open the Noctalia launcher.
2. Type `/ts`, optionally followed by part of a session or project name.
3. Select a result:
   - If that session is already attached in a Ghostty window, the plugin focuses that window through Hyprland.
   - Otherwise, it opens a new terminal and runs `sesh connect` for the selection.

The provider delegates discovery and connection to Sesh, so its `sesh.toml` configuration, source ordering, blacklist, and configured multiplexer are respected. Ghostty-window focusing is available only on Hyprland; other environments use the new-terminal fallback.

### Mise

Noctalia may not inherit the `PATH` configured by your interactive shell. If Sesh is installed with Mise and the provider reports that it cannot find `sesh`, set **Sesh command** in the plugin settings to:

```
~/.local/share/mise/shims/sesh
```
