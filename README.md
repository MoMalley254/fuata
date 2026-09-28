# Fuata

**Follow your money.** 

A private, local-first Android app that shows, at a glance, how much you have across cash, mobile money, banks and cards, how much you've spent today, to whom, and where money came from. No account, no server, no internet permission: everything stays on your phone.

> Status: in development (target: v0.1.0)

## Why

Spending is scattered across cash, mobile money and bank transactions, and reconciling it by hand is a chore. Fuata gives a single, glanceable answer to "Am I okay today?", including a persistent notification banner that shows what's left and whether you're safe, close to your limit, over it, or overdrawn.

## Principles

- **Private by design:** no network access, no telemetry, no card or account numbers collected.
- **Simple by default, deep on demand:** show only what's needed, with more one tap away.
- **Yours:** you name your money, pick its look, and decide what you see.
## Docs

- [Requirements](docs/requirements.md)
- [UI design brief](docs/ui-design-brief.md)
- [Issue plan](docs/github-issues.md)
## Tech

Flutter (Android), Riverpod, drift/SQLite, local notifications. No backend.


## Notes
- Allows users to label parts of receiving messages. Labelled messages take key labels : code, amount, payee, date, balance and fee. Rest of the string past the last label is completely ignored. In future updates, allow users to choose whether to ignore or strictly match all strings. 