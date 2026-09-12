# termul agent

A shell script that publishes SSH hosts from this machine to the TerMul app
as QR codes — no network, no backend, no account. Your `~/.ssh/config` and
key files never leave this machine except onto your own screen, for your
own phone's camera to read.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/febrianrz/Termul/main/agent/install.sh | sh
```

This installs a `termul` command and, on macOS with Homebrew, installs its
one dependency ([`qrencode`](https://fukuchi.org/works/qrencode/)) if it's
missing.

## Use

```bash
termul
```

It reads `~/.ssh/config` (matching each `Host` block that has a resolvable
`IdentityFile` to its `HostName`/`User`/`Port`) plus any other private keys
it finds directly in `~/.ssh`, and lists them as a numbered checklist.
Pick the ones you want (space-separated numbers), and it shows one QR code
per host, one at a time — press Enter after each is scanned to move to the
next.

In the TerMul app, open **Import dari Mac** from the host list and scan
each code as it appears; it opens the usual add-host form pre-filled so you
can review (or fix the address/username, if it wasn't in your ssh config)
before saving.

## Why one QR per host

A QR code holds a few KB at most. An RSA key alone can be close to that
limit, so bundling several hosts into one code isn't reliable. One code per
host keeps every scan comfortably within capacity, regardless of key type
or size.

## What gets read

Only files under `~/.ssh`: `config` (parsed, never sent anywhere) and
whichever private key files you explicitly pick. Password-authenticated
hosts aren't supported here — there's no local secret to read for those,
so add them by hand in the app.
