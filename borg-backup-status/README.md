# Borg Backup Status

A small Noctalia bar widget for a Borg backup status that is legible at a glance:

| State | Icon | Hover tooltip |
| --- | --- | --- |
| Current | `archive-restore` | Backup current |
| Running | `rotate-cw` | Backup running |
| Failed / overdue | `triangle-alert` | Backup failed |
| Removable disk missing | `hard-drive-off` | Disk unavailable |

## Install

Place (or symlink) this directory in Noctalia's plugin directory, enable **Borg Backup Status** in Settings, then add `syphar/borg-backup-status:backup` from the bar's Add-widget picker.

## Borg setup

After adding the widget, open its gear (or middle-click it) to set **Borg repository** to the same repository used by Borg or Pika, for example `/run/media/me/Backup/borg` or `ssh://borg@example.net/./repo`. Optionally set **Required disk path** to the mount point of a removable disk. The widget checks the most recent archive once per minute; an archive older than **Maximum backup age** is reported as failed/overdue. Its eight-day default fits a weekly schedule.

Set **Open command** in the plugin's settings to the backup app or script you want to launch on click. It defaults to `pika-backup`. Trigger an immediate refresh with:

```sh
noctalia msg plugin syphar/borg-backup-status:backup all refresh
```

## Test the Borg probe

Run the included script without Noctalia to see the exact state the widget would report:

```sh
./borg-probe.sh /run/media/me/Backup/borg /run/media/me/Backup 192
```

The arguments are repository, optional required mount path, and optional maximum backup age in hours. It requires Borg 1 and only queries Borg; it never changes the repository. The probe auto-acknowledges the configured repository and waits at most one second for a Borg lock. Diagnostic progress is written to stderr while its final state stays on stdout. A query is stopped after 30 seconds by default; override that only when needed with `BORG_PROBE_TIMEOUT_SECONDS=60`.
