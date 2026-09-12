# Termul Backend

Skeleton service for Termul's future auth (SSO) and cross-device sync
(host list, credentials metadata, snippets) between the mobile apps and
the desktop client. Not wired into the mobile app yet — the app
currently stores everything locally on-device.

## Status

Just a runnable base right now: Express + TypeScript with a `/health`
endpoint. Auth and sync endpoints are not implemented — those come once
the SSO provider(s) and sync storage are decided.

## Run locally

```bash
npm install
npm run dev
```

## Planned scope (not yet implemented)

- SSO login (OIDC/OAuth2 — provider(s) TBD)
- Sync API for saved hosts, connection settings, and snippets across
  Macbook / Android / iOS
- Secrets (passwords, private keys) stay encrypted client-side; the
  backend should never see them in plaintext
