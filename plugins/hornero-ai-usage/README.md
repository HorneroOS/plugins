# Hornero AI Usage

Dashboard card (`"placement": "dashboard"`) showing local AI
assistant usage from the typed contract
`horneroctl assistant usage --json`, refreshed every 60 seconds
(and on click): sessions, API calls, input/output/total tokens
and model names when the CLI reports them.

## Honest limits

- Quota is explicitly **unknown**: the provider does not expose a
  limit, so this card never invents one.
- No data is not zero usage: a failed or unparseable CLI response
  shows an error state instead of fabricated zeros.

## Privacy by construction

- One declared process command (`horneroctl`), no network hosts,
  no settings. Read-only; it never starts or stops a session.

Original HorneroOS code, MIT licensed. Plugin QML runs with your
user privileges inside Quickshell; it is not sandboxed.
