# Sesh Provider for Noctalia

A Noctalia launcher provider for [Sesh](https://github.com/joshmedeski/sesh), the smart tmux session manager.

Type `/sesh` in the Noctalia launcher to search Sesh's live tmux sessions, configured sessions, tmuxinator configurations, and zoxide projects. Selecting an entry focuses the existing Ghostty window when the session is already attached; otherwise it opens a new terminal and runs `sesh connect`.

## Requirements

- Noctalia v5.0.0 or later
- [`sesh`](https://github.com/joshmedeski/sesh)
- A tmux-compatible multiplexer (tmux by default, as configured in Sesh)

## Installation

Clone this repository into Noctalia's plugins directory, then enable **Sesh Provider** in Noctalia's plugin settings.

## Usage

1. Open the Noctalia launcher.
2. Type `/sesh`, optionally followed by part of a session or project name.
3. Select a result and press Enter to connect to it in your terminal.

The provider delegates discovery and connection to Sesh, so its `sesh.toml` configuration, source ordering, blacklist, and configured multiplexer are respected.

### Mise

Noctalia may not inherit the `PATH` configured by your interactive shell. If Sesh is installed with Mise and the provider reports that it cannot find `sesh`, set **Sesh command** in the plugin settings to:

```
~/.local/share/mise/shims/sesh
```
