# Hornero Calculator

Dashboard card (`"placement": "dashboard"`) that computes
arithmetic expressions with a hand-written tokenizer and
recursive-descent parser in JavaScript. Supports `+`, `-`, `*`,
`/`, `%`, parentheses, decimals and unary minus. No dynamic code
execution is used. Division or modulo by zero, malformed input
and non-finite results show `Error` instead of `Infinity`/`NaN`.

Type an expression or use the button grid; `=` computes and `C`
clears. No processes, no network, no settings. Original
HorneroOS code, MIT licensed. Plugin QML runs with your user
privileges inside Quickshell; it is not sandboxed.
