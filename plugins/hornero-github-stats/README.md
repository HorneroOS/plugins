# Hornero Dev Pulse

GitHub development activity for HorneroOS, local-first: contributions,
pull requests, reviews, an actionable development inbox, and an
optional side-by-side with Agent Deck AI usage.

## Data and privacy

All GitHub access goes through `horneroctl github ... --json`, which
uses the official GitHub CLI (`gh`) with literal argv. `gh` owns
authentication: this extension never asks for, reads, logs or stores
a token, never runs `gh`, and contains no network code. Install `gh`
and sign in once:

```bash
sudo pacman -S github-cli
gh auth login
```

Statistics follow `docs/github-contract.md` in HorneroOS/hornero:
contributions recognized by GitHub over the selected window,
search-partitioned PR/issue totals by actual event date, and inbox
items with real GitHub URLs. Unknown metrics are omitted, never
zero-filled, and truncation is flagged.

The Agent Deck comparison is temporal association only: machine-local
AI token buckets beside GitHub activity for the same dates. No pull
request is attributed to an agent from timing alone.

## Surfaces

- Bar indicator with open PRs, failing checks and review requests,
  plus a quick popover.
- A real top-level **Dev Pulse** Dashboard tab (PluginKit 5).
- A compact dashboard card.

Settings (Control Center → Extensions): refresh interval, activity
window, optional organization/repository filters, and governed
companion reactions (failing checks, review requests) on genuine
transitions only.

Exports stay local: `horneroctl github export --format markdown
--output report.md` (`--public-only` drops private repositories).
