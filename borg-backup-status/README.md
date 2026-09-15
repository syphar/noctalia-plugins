# Borg Backup Status

A small Noctalia bar widget for a Borg backup status that is legible at a glance:

| State | Icon | Hover tooltip |
| --- | --- | --- |
| Current | `archive-restore` | Backup current |
| Running | `rotate-cw` | Backup running |
| Failed / overdue | `triangle-alert` | Backup failed |
| Required directory missing | `hard-drive-off` | Disk unavailable |
| Repository not configured | `circle-help` | Backup not configured |

## Requirements

- Noctalia with support for plugin API 3 or newer
- Borg 1 (`borg`)
- Bash, `pgrep`, `timeout`, `head`, and GNU-compatible `date -d`
- The configured click command, if used (`pika-backup` by default)

The repository must be readable without interactive prompts from Noctalia's
environment. The probe disconnects stdin; configure any credentials needed for
encrypted or remote repositories accordingly.

## Install

From the root of this checkout:

```sh
mkdir -p "${XDG_DATA_HOME:-$HOME/.local/share}/noctalia/plugins/borg-backup-status"
cp -R borg-backup-status/. "${XDG_DATA_HOME:-$HOME/.local/share}/noctalia/plugins/borg-backup-status/"
```

Enable **Borg Backup Status** in Noctalia's plugin settings, then add
`syphar/borg-backup-status:backup` from the bar's Add-widget picker. Reload
Noctalia's configuration if the plugin is not listed yet.

## Borg setup

After adding the widget, open its gear (or middle-click it) to set **Borg repository** to the same repository used by Borg or Pika, for example `/run/media/me/Backup/borg` or `ssh://borg@example.net/./repo`. Optionally set **Required disk path** to the mount point of a removable disk. The widget checks the most recent archive once per minute; an archive older than **Maximum backup age** is reported as failed/overdue. Its eight-day default fits a weekly schedule.

Status checks follow this order:

1. An empty repository setting shows **Backup not configured**.
2. Any process matching the probe's Borg process check shows **Backup running**,
   even if it is working on another repository or performing another Borg operation.
3. A missing **Required disk path** shows **Disk unavailable**. This only checks
   that the directory exists; an existing, unmounted mount-point directory passes.
4. Otherwise, the probe queries the latest archive timestamp. A recent archive
   shows **Backup current**. An overdue archive, missing or invalid timestamp, or
   timed-out query shows **Backup failed**. Widget command failures also show failed.

The status reflects archive age and process activity; it does not verify archive
integrity or report the outcome of the most recent backup attempt.

Set **Open command** in the plugin's settings to the backup app or script you want to launch on click. It defaults to `pika-backup`. Trigger an immediate refresh with:

```sh
noctalia msg plugin syphar/borg-backup-status:backup all refresh
```

Use `status` in place of `refresh` to show a notification with the displayed state.

## Test the Borg probe

From the repository root, run the included script without Noctalia to inspect a
configured repository:

```sh
./borg-backup-status/borg-probe.sh /run/media/me/Backup/borg /run/media/me/Backup 192
```

The arguments are repository, optional required mount path, and optional maximum backup age in hours. It requires Borg 1 and only queries Borg; it never changes the repository. The probe auto-acknowledges the configured repository and waits at most one second for a Borg lock. Diagnostic progress is written to stderr while its final state stays on stdout. A query is stopped after 30 seconds by default; override that only when needed with `BORG_PROBE_TIMEOUT_SECONDS=60`.
