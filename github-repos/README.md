# GitHub Repositories for Noctalia v5

A standalone Luau launcher plugin. Requires Noctalia plugin API 24 or newer,
GitHub CLI (`gh`), and `xdg-open`.

## Install

Authenticate GitHub CLI with access to the repositories you want to search:

```sh
gh auth login --hostname github.com
```

From the root of this checkout, copy the plugin into Noctalia's local plugin directory:

```sh
mkdir -p "${XDG_DATA_HOME:-$HOME/.local/share}/noctalia/plugins/github-repos"
cp -R github-repos/. "${XDG_DATA_HOME:-$HOME/.local/share}/noctalia/plugins/github-repos/"
```

Enable **GitHub Repositories** in Noctalia's plugin settings. Reload Noctalia's
configuration if the new plugin is not listed yet.

## Use

| Query | Behavior |
| --- | --- |
| `/repo SEARCH` | Fuzzy search accessible, watched, and organization repositories. |
| `/repo` | Show up to 50 repositories from the cached list. |
| `/gh SEARCH` | Search GitHub repositories, returning up to 50 results in GitHub's relevance order. |
| `/gh terminal language:rust` | Use GitHub's repository search qualifiers. |

Press Enter to open a repository in your browser. Noctalia adds its common command
prefix (`/` by default) to the registered words `repo` and `gh`; use your configured
prefix if different.

`repo` fetches `/user/repos`, `/user/subscriptions`, and `/orgs/ORG/repos` for every organization
returned by `/user/orgs`. It fetches all pages with `per_page=100`, without
`affiliation`, `sort`, or `direction` filters, and deduplicates by repository ID.
Forks and archives are included. Repository names (`owner/name`) are matched
locally with Noctalia's fuzzy matcher. Private repositories require access through
the active GitHub CLI credentials.

For `/repo`, the search term filters matching repository names. Matches are
ordered by non-forks before forks, then source (accessible, watched, organization),
then fuzzy score, then alphabetical `owner/name`.
These priorities apply even when a lower-priority repository has a better or
exact name match. Repositories in multiple sources keep their highest source
priority. With an empty query, the same priorities apply, followed by collection order. Up to 50 results
are displayed. `/gh` retains GitHub's relevance order.

The combined repository list is cached in memory for 24 hours; subsequent searches
refresh expired data in the background. Failed refreshes retain the old list and
retry on a query after 15 seconds. GitHub-wide requests are debounced by 350 ms,
with one request in flight and a one-minute cache of the last successful query.
Only the latest query is displayed. Caches clear when the plugin reloads; reload
after switching GitHub CLI accounts or logging out. No tokens are stored by this
plugin, and all API requests explicitly target github.com.

## Development

```sh
noctalia plugins lint github-repos
lua tests/run.lua
```

Run these commands from the repository root. The test runner resolves the plugin
relative to its own location, so it can also be invoked from other directories.

The tests run the Lua-compatible Luau source against a mocked Noctalia host. A
running Noctalia session is still needed to verify the launcher UI and browser.

References: [Noctalia launcher API](https://docs.noctalia.dev/noctalia/plugins/development/entries/),
[runtime API](https://docs.noctalia.dev/noctalia/plugins/development/runtime-api/),
[local installation](https://docs.noctalia.dev/noctalia/plugins/development/workflow/),
and [GitHub CLI API](https://cli.github.com/manual/gh_api).
