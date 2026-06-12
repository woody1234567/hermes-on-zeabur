# Hermes on Zeabur

This repository contains the minimal deployment assets for running Hermes Agent
on Zeabur with Dockerfile-based deployment.

The service uses the official Hermes Agent Docker image, starts Hermes in
gateway mode, exposes the OpenAI-compatible API, and can optionally expose the
Hermes dashboard.

## Files

| File | Purpose |
| --- | --- |
| `Dockerfile` | Minimal wrapper around the pinned official Hermes Agent image. Zeabur auto-detects this file for Dockerfile-based deployment. |
| `.dockerignore` | Keeps local secrets, Hermes state, skills, and docs out of the Docker build context. |
| `.gitignore` | Prevents `.env` from being committed. |
| `skills-lock.json` | Lock file for Zeabur-related agent skills used by this workspace. |
| `.env` | Local reference for runtime variables. This file contains secrets and must not be committed. |

## Dockerfile Deployment

Zeabur automatically deploys this repository with Docker because a root
`Dockerfile` is present.

The Dockerfile intentionally pins the image:

```dockerfile
FROM nousresearch/hermes-agent:v2026.6.5
```

Do not switch this to `latest` or `main` unless the floating image has been
verified on Zeabur. The floating tags changed on 2026-06-12 and previously
failed during startup because `s6-setuidgid` was missing from the image.

The container starts with:

```text
/opt/hermes/docker/entrypoint.sh gateway run
```

This is required for container platforms. Running the default interactive Hermes
CLI would exit because there is no attached terminal.

## Required Zeabur Service Settings

Configure these settings on the Zeabur service after creating it from this
repository.

| Setting | Value | Why |
| --- | --- | --- |
| Deployment method | Dockerfile | Zeabur should detect the root `Dockerfile` automatically. |
| Persistent volume mount path | `/opt/data` | Hermes stores config, API keys, sessions, memories, skills, profiles, and logs here. |
| API HTTP port | `8642` | Hermes gateway OpenAI-compatible API and health endpoint. |
| Dashboard HTTP port | `9119` | Hermes dashboard, only useful when dashboard env vars are enabled. |
| Resource size | At least 2 CPU / 4 GB memory recommended | Hermes can run tools, browsers, skills, and multiple gateway processes. |

Do not run two Hermes gateway containers against the same `/opt/data` volume at
the same time. Hermes session and memory files are not designed for concurrent
writes from multiple containers.

## Required Environment Variables

Add these variables in the Zeabur service environment variables page.

| Variable | Required | Example | Notes |
| --- | --- | --- | --- |
| `OPENAI_API_KEY` | Yes | `sk-...` | Used by Hermes for model access when configured for OpenAI-compatible usage. Use the real secret value in Zeabur, not the example. |
| `API_SERVER_ENABLED` | Yes | `true` | Enables the gateway API server. |
| `API_SERVER_HOST` | Yes | `0.0.0.0` | Required so the API server is reachable from outside the container. |
| `API_SERVER_PORT` | Recommended | `8642` | Hermes defaults to `8642`; set it explicitly so the Zeabur HTTP port and Hermes API port stay aligned. |
| `API_SERVER_KEY` | Yes | `openssl rand -hex 32` | Bearer token for the Hermes API. This must match the API key configured in Open WebUI. Hermes requires at least 8 characters; use a long random value. |
| `API_SERVER_CORS_ORIGINS` | Optional | `*` | Not required for Open WebUI because Open WebUI connects server-to-server. Use this only for browser-based clients that call Hermes directly. |
| `HERMES_DASHBOARD` | Optional | `1` | Enables the supervised Hermes dashboard service. |
| `HERMES_DASHBOARD_HOST` | Required if dashboard is enabled | `0.0.0.0` | Required so the dashboard is reachable through Zeabur networking. |
| `HERMES_DASHBOARD_PORT` | Required if dashboard is enabled | `9119` | Must match the dashboard HTTP port configured in Zeabur. |

## Dashboard Authentication

If `HERMES_DASHBOARD=1` and the dashboard is exposed publicly, configure
authentication. The dashboard can expose sensitive data such as API keys,
sessions, and agent state.

Recommended options:

| Variable | When to use |
| --- | --- |
| `HERMES_DASHBOARD_BASIC_AUTH_USERNAME` | Basic username/password auth for trusted private deployments. |
| `HERMES_DASHBOARD_BASIC_AUTH_PASSWORD` | Basic username/password auth for trusted private deployments. |
| `HERMES_DASHBOARD_BASIC_AUTH_SECRET` | Stable session signing secret for basic auth across restarts. |
| `HERMES_DASHBOARD_OAUTH_CLIENT_ID` | Nous Portal OAuth for public hosted deployments. |
| `HERMES_DASHBOARD_OIDC_ISSUER` | Self-hosted OpenID Connect provider. |
| `HERMES_DASHBOARD_OIDC_CLIENT_ID` | Self-hosted OpenID Connect provider. |

For short-lived testing only, you can set:

```dotenv
HERMES_DASHBOARD_INSECURE=1
```

Do not use `HERMES_DASHBOARD_INSECURE=1` for a public production service unless
another trusted auth layer sits in front of Zeabur.

## Minimal API-Only Configuration

Use this when you only need the OpenAI-compatible gateway API.

```dotenv
OPENAI_API_KEY=sk-...
API_SERVER_ENABLED=true
API_SERVER_HOST=0.0.0.0
API_SERVER_PORT=8642
API_SERVER_KEY=<long-random-secret>
```

Zeabur settings:

```text
Volume: /opt/data
HTTP port: 8642
```

## API Plus Dashboard Configuration

Use this when you also want the Hermes dashboard.

```dotenv
OPENAI_API_KEY=sk-...
API_SERVER_ENABLED=true
API_SERVER_HOST=0.0.0.0
API_SERVER_PORT=8642
API_SERVER_KEY=<long-random-secret>
HERMES_DASHBOARD=1
HERMES_DASHBOARD_HOST=0.0.0.0
HERMES_DASHBOARD_PORT=9119

# Choose one dashboard auth method before exposing this publicly.
HERMES_DASHBOARD_BASIC_AUTH_USERNAME=<username>
HERMES_DASHBOARD_BASIC_AUTH_PASSWORD=<strong-password>
HERMES_DASHBOARD_BASIC_AUTH_SECRET=<long-random-secret>
```

Zeabur settings:

```text
Volume: /opt/data
HTTP ports: 8642, 9119
```

## Connecting Open WebUI

In Open WebUI, add Hermes as an OpenAI-compatible connection.

| Setting | Value |
| --- | --- |
| URL | `https://<your-hermes-zeabur-domain>/v1` |
| API Key | The exact same value as `API_SERVER_KEY` |
| API Type | Chat Completions |

The `/v1` suffix is required. Open WebUI may pass its basic connection test
without `/v1`, but model listing will fail.

If you deploy Open WebUI as a separate service, set these Open WebUI variables
on first launch:

```dotenv
OPENAI_API_BASE_URL=https://<your-hermes-zeabur-domain>/v1
OPENAI_API_KEY=<same-value-as-API_SERVER_KEY>
ENABLE_OLLAMA_API=false
```

`ENABLE_OLLAMA_API=false` is optional, but it keeps an empty Ollama backend from
appearing above Hermes models in the Open WebUI model picker.

Open WebUI stores connection settings in its database after first launch. If you
change the URL or key later, update the connection in Admin Settings or reset
the Open WebUI data volume.

## Verifying The Hermes API

After deployment, verify the Zeabur URL from your local machine:

```bash
curl https://<your-hermes-zeabur-domain>/health
curl -H "Authorization: Bearer <same-value-as-API_SERVER_KEY>" \
  https://<your-hermes-zeabur-domain>/v1/models
```

The health endpoint should return a status payload, and `/v1/models` should list
the Hermes agent model.

## Managing Variables With Zeabur CLI

Prefer the Zeabur dashboard for secrets. If using the CLI, always invoke it with
`npx zeabur@latest`.

Create variables:

```bash
npx zeabur@latest variable create --id <service-id> \
  -k "API_SERVER_ENABLED=true" \
  -k "API_SERVER_HOST=0.0.0.0" \
  -k "API_SERVER_PORT=8642" \
  -y -i=false
```

Update existing variables:

```bash
npx zeabur@latest variable update --id <service-id> \
  -k "API_SERVER_HOST=0.0.0.0" \
  -k "API_SERVER_PORT=8642" \
  -y -i=false
```

Avoid `variable env --id <service-id> -f .env` unless you intentionally want to
replace the entire variable set on the service. That command removes existing
variables not present in the file.

Restart the service after changing runtime variables.

## Deployment Checklist

1. Deploy this repository to Zeabur as a Dockerfile service.
2. Add a persistent volume mounted at `/opt/data`.
3. Add HTTP port `8642`.
4. Add HTTP port `9119` only if using the dashboard.
5. Add the required environment variables.
6. Restart or redeploy the service after changing variables or volume settings.
7. Check Zeabur runtime logs for Hermes gateway startup messages.
8. Verify `/health` and authenticated `/v1/models` on the Zeabur domain.
9. Configure Open WebUI with `https://<your-hermes-zeabur-domain>/v1` and the
   same value as `API_SERVER_KEY`.
10. Configure dashboard authentication before exposing dashboard publicly.

## Current Known Limitations

- This repository currently does not include a Zeabur template YAML or deployment
  script. Use Zeabur's Dockerfile deployment flow from the dashboard or CLI.
- Local `.env` is only a reference and is excluded from the Docker build context.
- Dockerfile deployment cannot declare Zeabur volumes by itself; configure the
  `/opt/data` mount in Zeabur.
