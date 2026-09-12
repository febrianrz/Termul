# termul agent

A shell script that publishes SSH hosts from this machine to the TerMul app
as QR codes — no network, no backend, no account. Your `~/.ssh/config` and
key files never leave this machine except onto your own screen, for your
own phone's camera to read.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/febrianrz/Termul/main/agent/install.sh | sh
```

Works on macOS and Linux (bash + standard Unix tools only). This installs
a `termul` command and installs its one dependency
([`qrencode`](https://fukuchi.org/works/qrencode/)) if it's missing, via
Homebrew, apt, dnf, pacman, or zypper — whichever is available.

## Use

```bash
termul
```

It reads `~/.ssh/config` (matching each `Host` block that has a resolvable
`IdentityFile` to its `HostName`/`User`/`Port`) plus any other private keys
it finds directly in `~/.ssh`, and lists them as a numbered checklist.
Pick the ones you want (space-separated numbers), and it packs as many of
them as fit into each QR code — for a handful of hosts with modern keys
(ed25519/ecdsa) that's usually just one QR for the whole batch. A host
whose own key is already large (a big RSA key) gets a QR to itself instead
of failing to fit; if you selected more hosts than one QR can hold, it
shows the next one after you press Enter.

In the TerMul app, open **Import dari Komputer** from the host list and
scan each code as it appears. Each one shows a confirmation listing every
host it contains before saving them - review the list (or cancel and fix
the address/username in the app afterward, if it wasn't in your ssh
config).

## Why hosts sometimes still get their own QR code

A QR code holds a few KB at most, and an RSA key alone can be close to
that. Hosts are grouped into a QR code up to a safe size budget; a host
that would push a group over budget starts a new one instead of making
the code too dense to scan reliably.

## What gets read

Only files under `~/.ssh`: `config` (parsed, never sent anywhere) and
whichever private key files you explicitly pick. Password-authenticated
hosts aren't supported here — there's no local secret to read for those,
so add them by hand in the app.
