# Hermes on Zeabur

This repository contains the Zeabur deployment assets for running
Hermes Agent with the official Docker image.

The deployment runs Hermes in gateway mode, exposes an OpenAI-compatible API,
enables the Hermes dashboard, and persists Hermes state on a Zeabur volume.

## Features

- Deploys with a root `Dockerfile` for Zeabur Dockerfile-based deployment.
- Deploys `nousresearch/hermes-agent:v2026.6.5` as a Zeabur `PREBUILT_V2` service.
- Starts Hermes with `/opt/hermes/docker/entrypoint.sh gateway run`, which keeps
  the container running as a gateway service instead of launching the interactive
  CLI.
- Exposes the Hermes API on port `8642`.
- Exposes the Hermes dashboard on port `9119`.
- Stores persistent Hermes data in `/opt/data`, including sessions, memories,
  skills, logs, and generated configuration files.
- Loads deployment secrets and runtime settings from `.env`.

## Files

| File | Purpose |
| --- | --- |
| `Dockerfile` | Minimal Dockerfile wrapper around the pinned official Hermes Agent image. Zeabur auto-detects this file for Dockerfile-based deployment. |
| `.dockerignore` | Keeps local secrets, Hermes state, and template-only files out of the Docker build context. |
| `zeabur.hermes.yaml` | Zeabur template that defines the Hermes Agent Docker service, ports, volume, domains, and environment variables. |
| `deploy-hermes-zeabur.sh` | Deployment script that loads `.env` and deploys the template to Zeabur with `npx zeabur@latest template deploy`. |
| `CLAUDE.md` | Local deployment notes, including the target Zeabur project, active service ID, and public URLs. |
| `skills-lock.json` | Lock file for Zeabur-related agent skills used by this workspace. |
| `.env` | Local environment file for deployment variables. This file contains secrets and should not be committed. |

## Environment Variables

The deployment script expects these values in `.env`:

```dotenv
OPENAI_API_KEY=...
API_SERVER_KEY=...
API_SERVER_CORS_ORIGINS=*
```

The template also configures these runtime values automatically:

```dotenv
API_SERVER_ENABLED=true
API_SERVER_HOST=0.0.0.0
HERMES_DASHBOARD=1
HERMES_DASHBOARD_HOST=0.0.0.0
HERMES_DASHBOARD_PORT=9119
```

Optional deployment overrides can be passed as shell environment variables:

```bash
PROJECT_ID=project-... \
API_DOMAIN=my-hermes-api \
DASHBOARD_DOMAIN=my-hermes-dashboard \
bash deploy-hermes-zeabur.sh
```

The template pins the Hermes image to `nousresearch/hermes-agent:v2026.6.5` instead of `latest`. The `latest`/`main` tags were updated on 2026-06-12 and the deployed container failed during startup because `s6-setuidgid` was missing from the image.

## Dockerfile Deployment

Use this flow when you want Zeabur to build from the repository `Dockerfile`.
Zeabur automatically detects a root-level `Dockerfile` and deploys with Docker.

1. Push this repository to GitHub, or deploy the current directory directly with the Zeabur CLI.
2. In the Zeabur service, add a persistent volume mounted at `/opt/data`.
3. Configure HTTP ports `8642` and, if using the dashboard, `9119`.
4. Add the required environment variables from the section above.
5. Deploy the service.

The Dockerfile intentionally pins:

```dockerfile
FROM nousresearch/hermes-agent:v2026.6.5
```

Do not switch it to `latest` or `main` unless you have verified that the
floating image boots correctly on Zeabur.

## Template Deployment

Install Node.js and make sure the Zeabur CLI can run through `npx`. Then deploy:

```bash
bash deploy-hermes-zeabur.sh
```

By default, the script deploys to:

```text
project-6a041690dd502f86055b715b
```

Default public domain prefixes:

```text
API: hermes-api-6a041690
Dashboard: hermes-dashboard-6a041690
```

The script uses:

```bash
npx zeabur@latest template deploy \
  -i=false \
  --json \
  -f zeabur.hermes.yaml \
  --project-id "$PROJECT_ID"
```

## Current Deployment

The latest recorded active deployment is:

| Field | Value |
| --- | --- |
| Project ID | `project-6a041690dd502f86055b715b` |
| Service ID | `6a043738dd502f86055b7d58` |
| Service name | `hermes-agent-inal` |
| API URL | `https://hermes-api-6a041690.zeabur.app` |
| Dashboard URL | `https://hermes-dashboard-6a041690.zeabur.app` |

## Notes

- Do not commit `.env`; it contains API keys and service credentials.
- Run `bash tests/check-hermes-template.sh` before deployment if you edit the template. It verifies that the Hermes image is not using a floating `latest`/`main` tag.
- The Hermes service must run in gateway mode for a container platform. Running
  the default interactive CLI in Zeabur causes the container to exit because
  there is no terminal attached.
- The Zeabur template mounts `/opt/data` so Hermes state survives restarts and
  redeployments.
