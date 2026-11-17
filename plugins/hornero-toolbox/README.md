# Hornero Toolbox

Seven everyday tools in one Signal dashboard card (PluginKit 3,
`schemaVersion: 3`): **Calculator** (expression field and keypad), **Units**
(length, mass, data sizes, temperature), **Base** (decimal to binary/octal/hex
and hex to decimal), **Colour** (hex to RGB/HSL with WCAG contrast on white
and black), **Dates** (days between, add days, UTC arithmetic), **JSON**
(format and minify with the parser's error) and **Text** (case transforms,
counts).

It replaces Calculator, Unit Converter, Base Converter, Colour Converter, Date
Calculator, JSON Tools and Text Tools, which are deprecated in the catalogue
and keep working for anyone who has them installed. Their stored settings do
not carry over (new id); every setting has a typed default here.

Everything is local arithmetic. No process, no network, nothing stored except
settings. Results update as you type and invalid input is stated, never
guessed. The calculator accepts only numbers, `+ - * / % ( )`: there is no
`eval`.

## Settings

`defaultTool`, `showKeypad`, `precision` (0-10), `defaultCategory`,
`uppercaseHex`, `defaultHex`, `showUtcNote`, `indentSpaces` (0-8),
`defaultTextMode`, `showCounts`.

## Enable

```sh
horneroctl plugin catalog install hornero-toolbox --yes
horneroctl plugin enable hornero-toolbox --yes
```

Plugin QML runs with your user privileges inside Quickshell; it is not
sandboxed. Original HorneroOS code, MIT licensed.

## PluginKit 3

Colours, type, spacing and glyphs come from the shared Theme tokens.
