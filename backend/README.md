# Termul Backend

Brokers the SSO login flow so the OAuth `client_secret` never has to ship
inside the mobile app: the app gets an authorization `code` from the
browser redirect and sends it here; this service exchanges it for tokens
with your SSO server and hands them back over HTTPS. Will also host
cross-device sync (host list, snippets) in the future.

Works with any OAuth2 Authorization Code Grant server shaped like Laravel
Passport (`/oauth/authorize`, `/oauth/token`, `/api/user`, `/api/logout`) —
just point `SSO_BASE_URL` at it. No code changes needed to use a different
SSO provider, as long as it follows that same shape.

## Endpoints

- `GET /health` — liveness check
- `POST /auth/exchange` — body `{ "code": "..." }`, returns the SSO server's token response (`access_token`, `refresh_token`, `expires_in`, `token_type`)
- `POST /auth/refresh` — body `{ "refresh_token": "..." }`, same response shape

## Run locally

```bash
cp .env.example .env   # fill in SSO_CLIENT_ID / SSO_CLIENT_SECRET
npm install
npm run dev
```

## Run with Docker

```bash
docker pull <your-image>   # e.g. <dockerhub-username>/termul-backend:latest,
                            # or <registry-host>/<username>/termul-backend:latest
docker run -d -p 3000:3000 --env-file .env <your-image>
```

The image is built and pushed automatically by `.github/workflows/backend-docker.yml`
whenever files under `backend/` change, to Docker Hub by default. To push
to your own registry instead (self-hosted, GHCR, etc.), set these in
**Settings → Secrets and variables → Actions**:

| Name | Type | Value |
| --- | --- | --- |
| `DOCKER_REGISTRY` | secret | your registry's host, e.g. `registry.example.com` (leave unset/empty for Docker Hub) |
| `DOCKER_USERNAME` | secret | your registry username |
| `DOCKER_PASSWORD` | secret | your registry password or access token |
| `DOCKER_IMAGE_NAMESPACE` | secret, optional | the "project"/namespace segment of the image path, if it's different from `DOCKER_USERNAME` (e.g. some registries, like Harbor, log in with an email address but use a separate project name for image paths) |

The pushed image is then `<DOCKER_REGISTRY>/<namespace>/termul-backend`
(or just `<namespace>/termul-backend` on Docker Hub, no `DOCKER_REGISTRY`
needed there), where `<namespace>` is `DOCKER_IMAGE_NAMESPACE` if set,
otherwise `DOCKER_USERNAME` with anything after `@` and any characters
invalid in a Docker image name stripped out. Your registry must be
reachable over the public internet — GitHub's hosted runners can't reach a
registry that's only on your local network or VPN.

## Deploying

You need a server that can run a Docker container and stay reachable over
the internet — a VPS (DigitalOcean, Hetzner, a home server with port
forwarding, etc.). Any provider works the same way:

1. **Install Docker** on the server (e.g. `curl -fsSL https://get.docker.com | sh`).
2. **Copy `.env.example` to `.env` on the server** and fill in your real
   `SSO_CLIENT_ID` / `SSO_CLIENT_SECRET` (and `SSO_BASE_URL` /
   `SSO_REDIRECT_URI` if you're not using this repo's defaults).
3. **Pull and run** — either directly:
   ```bash
   docker pull <your-image>
   docker run -d --name termul-backend --restart unless-stopped \
     -p 3000:3000 --env-file .env <your-image>
   ```
   or with the included `docker-compose.yml` (copy it to the server too):
   ```bash
   DOCKER_IMAGE=<your-image> docker compose up -d
   ```
4. **Put HTTPS in front of it.** Android blocks plain HTTP for apps by
   default, so the app's `BACKEND_BASE_URL` needs to be `https://` once
   it's not just talking to a local emulator. The easiest way is
   [Caddy](https://caddyserver.com/) — it gets you a Let's Encrypt
   certificate automatically:
   ```bash
   cp Caddyfile.example Caddyfile   # edit the domain to point at your server
   caddy run
   ```
   (or use nginx/Traefik/your platform's built-in HTTPS if you already have one.)
5. **Point the app at it** — set `BACKEND_BASE_URL=https://your-domain.example.com`
   in `dart_define.json` for local builds, and as a repository **variable**
   in GitHub Actions (Settings → Secrets and variables → Actions →
   Variables) so the CI-built APK picks it up too.

Redeploying a new version is just steps 3 again once `backend-docker.yml`
has pushed an updated `:latest` image (`docker compose pull && docker
compose up -d`, or the equivalent `docker pull` + `docker run`).

## Environment variables

| Variable | Required | Default |
| --- | --- | --- |
| `PORT` | no | `3000` |
| `SSO_BASE_URL` | no | `https://one.alterindonesia.com` |
| `SSO_CLIENT_ID` | yes | — |
| `SSO_CLIENT_SECRET` | yes | — |
| `SSO_REDIRECT_URI` | no | `com.febrianrz.termul://callback` — must exactly match the app's `SSO_REDIRECT_URI` |
