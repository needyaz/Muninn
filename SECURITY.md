# Security

## Reporting a vulnerability

Please report security problems privately through GitHub's **Report a vulnerability** button on the repository's Security tab, rather than
in a public issue. Include what you did, what you expected, and what happened. This is a one-person project, so expect a reply in days, not hours.

## What Muninn does and doesn't protect

- **No network access.** The app is sandboxed with incoming and outgoing connections disabled and contains no analytics or telemetry.
- **Data at rest is not encrypted.** History, snippets and blobs are stored unencrypted in the app's container
  (`~/Library/Application Support/Muninn/`), readable only by your user and excluded from backups. Any process running as you can read them.
- **Sensitive copies.** Items marked concealed by password managers are skipped by default. In Mask mode only a placeholder is stored, never the value.
  Transient items are never recorded.
- **Exports are not encrypted** and leave out sensitive items. Treat a `.muninn` file like your clipboard history.
- **Imports are untrusted input.** Filenames are validated, sizes are capped, and imported settings are validated; see `DataPorter.swift`.
- **Shortcuts.** The Shortcuts actions can read your non-sensitive history, so any shortcut you run can too.

## Supported versions

Only the latest release is supported.
