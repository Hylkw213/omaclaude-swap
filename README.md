# cswap Accounts

An [Omarchy](https://omarchy.org/) bar widget that shows every
[cswap](https://github.com/realiti4/claude-swap)-tracked Claude Code account
with live 5-hour session and 7-day weekly rate limits, and switches the
active account with a click.

![cswap Accounts panel](assets/preview.png)

## Requirements

This widget is a display/control surface for **[claude-swap](https://github.com/realiti4/claude-swap)**
(CLI: `cswap`) — it does not manage accounts itself and has nothing to show
without it. You don't need to set any of this up by hand first: the panel
walks you through it.

- Omarchy with the shell plugin system (`omarchy plugin` commands available)
- [`cswap`](https://github.com/realiti4/claude-swap), which this widget shells
  out to for `cswap list --json` and `cswap switch <target>`
- `python3` (used by `bin/cswap-roster` to reshape `cswap`'s output)

If `cswap` isn't installed, the panel shows an **Install cswap** row —
click it and Omarchy opens a terminal running `uv tool install claude-swap`.
Once installed, a **+** button next to "ACCOUNTS" (or, before any account is
registered, an **Add account** row) opens a terminal that runs
`claude auth login` — so the browser OAuth for the account you want to add
actually happens — then `cswap add` to register whatever's now signed in.
`cswap add` alone only snapshots the currently-logged-in session, so calling
it without a fresh login first just re-registers the account you're already
on. Don't log out of any existing account first; per claude-swap's own docs
that can revoke its refresh token — just sign in as the new one when
prompted.

`claude auth login` opens its OAuth URL in your normal default browser. If
that browser already has an active claude.com session, the consent screen
may go straight through as *that* account instead of asking for
credentials — use claude.com's own account switcher in that tab (or sign
out and back in as the new account) if that happens.

Both terminal actions launch a script under `bin/` and wait for a keypress
before closing, so you can see what happened; nothing installs or
authenticates silently in the background.

## Install

```bash
omarchy plugin add https://github.com/Hylkw213/omaclaude-accounts.git --enable
```

Or clone manually into `~/.config/omarchy/plugins/cswap.accounts/`. Editing
QML there hot-reloads for most changes, but a bar-widget's popup panel is a
long-lived instance — some changes (anything affecting the bar icon itself,
or a change that doesn't visibly apply after a save) need `omarchy restart
shell` to take effect on an already-open instance.

## Use

- Click the bar icon to open the panel.
- Each row shows an account's email, org, session (5h) and weekly (7d) usage
  meters, and when each resets.
- Click a row to switch the active Claude Code account to it (via
  `cswap switch`).

## Configuration

| Key | Default | What it does |
|---|---|---|
| `refreshIntervalSec` | `300` | How often the account list is re-fetched from `cswap` |

```bash
omarchy bar set cswap.accounts refreshIntervalSec 120 --json
```

## Remove

```bash
omarchy plugin remove cswap.accounts
```

This removes the widget only — it never touches `cswap` itself or any
account it manages. Uninstall `cswap` separately (`uv tool uninstall
claude-swap`) if you want that gone too.

## License

MIT — see [LICENSE](LICENSE).
