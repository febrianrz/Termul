# Termul Backend

Brokers the SSO login flow so the OAuth `client_secret` never has to ship
inside the mobile app: the app gets an authorization `code` from the
browser redirect and sends it here; this service exchanges it for tokens
with Alter Indonesia and hands them back over HTTPS. Will also host
cross-device sync (host list, snippets) in the future.

## Endpoints

- `GET /health` — liveness check
- `POST /auth/exchange` — body `{ "code": "..." }`, returns Alter Indonesia's token response (`access_token`, `refresh_token`, `expires_in`, `token_type`)
- `POST /auth/refresh` — body `{ "refresh_token": "..." }`, same response shape

## Run locally

```bash
cp .env.example .env   # fill in ALTER_CLIENT_ID / ALTER_CLIENT_SECRET
npm install
npm run dev
```

## Run with Docker

```bash
docker pull <your-dockerhub-username>/termul-backend:latest
docker run -d -p 3000:3000 --env-file .env <your-dockerhub-username>/termul-backend:latest
```

The image is built and pushed automatically by `.github/workflows/backend-docker.yml`
whenever files under `backend/` change (see the repo root README for the
required CI secrets).

## Environment variables

| Variable | Required | Default |
| --- | --- | --- |
| `PORT` | no | `3000` |
| `ALTER_BASE_URL` | no | `https://one.alterindonesia.com` |
| `ALTER_CLIENT_ID` | yes | — |
| `ALTER_CLIENT_SECRET` | yes | — |
| `ALTER_REDIRECT_URI` | no | `com.febrianrz.termul://callback` |
