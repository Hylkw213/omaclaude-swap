# cswap Accounts

An [Omarchy](https://omarchy.org/) bar widget that shows every
[cswap](https://github.com/search?q=claude-swap)-tracked Claude Code account
with live 5-hour session and 7-day weekly rate limits, and switches the
active account with a click.

![cswap Accounts panel](assets/preview.png)

## Requirements

- Omarchy with the shell plugin system (`omarchy plugin` commands available)
- [`cswap`](https://github.com/search?q=claude-swap) (`claude-swap`) installed
  and on `PATH`, in `~/.local/bin`, or as a `uv` tool — this widget shells out
  to `cswap list --json` and `cswap switch <target>` and does nothing on its
  own without it
- `python3` (used by `bin/cswap-roster` to reshape `cswap`'s output)

## Install

```bash
omarchy plugin add https://github.com/<you>/cswap-accounts.git --enable
```

Or clone manually into `~/.config/omarchy/plugins/cswap.accounts/` — the
shell hot-reloads plugin code on save, no restart required.

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

## License

MIT — see [LICENSE](LICENSE).
