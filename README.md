# Noctalia plugins

Luau plugins for Noctalia, with a separate manifest and README in each directory.

| Plugin | What it does | Declared plugin API |
| --- | --- | --- |
| [GitHub Repositories](github-repos/README.md) | Search accessible repositories with `/repo`, or search GitHub with `/gh`. | 24 |
| [Sesh Provider](tmux-sesh/README.md) | Find and connect to Sesh sessions and projects with `/ts`. | 3 |
| [Borg Backup Status](borg-backup-status/README.md) | Show archive freshness and Borg activity in the bar. | 3 |

Launcher examples use the default `/` command prefix.

## Installation

Install each plugin you want separately. From the root of this checkout, for example:

```sh
mkdir -p "${XDG_DATA_HOME:-$HOME/.local/share}/noctalia/plugins/tmux-sesh"
cp -R tmux-sesh/. "${XDG_DATA_HOME:-$HOME/.local/share}/noctalia/plugins/tmux-sesh/"
```

Replace `tmux-sesh` in both paths with `github-repos` or `borg-backup-status` to
install another plugin. Each installed directory should contain its own
`plugin.toml`. You can also symlink an individual plugin directory using its
absolute checkout path.

Enable the plugin in Noctalia's plugin settings. Reload Noctalia's configuration
if it is not listed yet. Follow the plugin's README for dependencies, authentication,
and configuration; the Borg widget must also be added to the bar.

To update a copied installation, repeat the copy after updating this checkout,
then reload the plugin.

## Development

Run from the repository root:

```sh
noctalia plugins lint github-repos
noctalia plugins lint tmux-sesh
noctalia plugins lint borg-backup-status
lua tests/run.lua
```

`just tests` also runs the Lua tests. The current suite covers only GitHub
Repositories, using a mocked Noctalia host. It does not exercise the live launcher,
browser, Sesh window focusing, or Borg widget. See the Borg README for a standalone
probe command, and verify UI behavior in a running Noctalia session.
