# Cool People List — deployment exercise

A small two-service web app (FastAPI backend + Streamlit frontend) used to practice containerization and image publishing during an internship.

---

## Table of contents

1. [Purpose and context](#purpose-and-context)
2. [Requirements → implementation map](#requirements--implementation-map)
3. [Architecture](#architecture)
4. [Tech stack](#tech-stack)
5. [REST API endpoints](#rest-api-endpoints)
6. [Service addresses and API docs](#service-addresses-and-api-docs)
7. [Environment variables](#environment-variables)
8. [Running locally](#running-locally)
9. [Docker / Docker Compose](#docker--docker-compose)
10. [Deployment workflow](#deployment-workflow)
11. [Image versioning policy](#image-versioning-policy)
12. [Testing](#testing)
13. [Continuous integration](#continuous-integration)
14. [Repository structure](#repository-structure)

---

## Purpose and context

This project is a deployment ("wdrożeniowe") exercise. The application itself is intentionally simple — a list of people with a "swag level" that can be joined and left — so the focus stays on the deployment side: splitting an app into independent services, containerizing each one, wiring them together with Docker Compose, and publishing versioned images to a registry.

---

## Requirements → implementation map

| Requirement | Implementation |
|---|---|
| **REST API (FastAPI)** | [backend/main.py](FirstApplication/backend/main.py) — `POST/GET/DELETE /people` endpoints, async handlers, auto-generated OpenAPI/Swagger docs |
| **Data validation (Pydantic)** | [backend/models.py](FirstApplication/backend/models.py) — `PersonIn`/`PersonOut`/`DeleteRequest`, field validators (non-empty names, no digits, birth date not in the future, swag level range, min password length, password must contain a letter and a number), automatic `422` on invalid input |
| **HTTP methods + status codes** | `POST /people` (200/422), `GET /people`, `GET /people/{id}` (404 if missing), `DELETE /people/{id}` (403 on wrong password, 404 if missing) |
| **Frontend UI** | [frontend/frontend.py](FirstApplication/frontend/frontend.py) — Streamlit form + table, talks to the backend only via REST (`API_URL`) |
| **Password handling** | Passwords are hashed with PBKDF2-HMAC-SHA256 + per-user salt in [backend/main.py](FirstApplication/backend/main.py); the plain password is never stored or returned |
| **Persistent storage (SQLite)** | [backend/main.py](FirstApplication/backend/main.py) — a SQLite database created on startup at `DATABASE_PATH`, persisted outside the container via a named Docker volume |
| **Containerization (Docker)** | Independent multi-stage [backend/Dockerfile](FirstApplication/backend/Dockerfile) and [frontend/Dockerfile](FirstApplication/frontend/Dockerfile), orchestrated by [docker-compose.yml](FirstApplication/docker-compose.yml) |
| **Configuration via environment variables** | `API_URL` and `DATABASE_PATH` env vars (see [Environment variables](#environment-variables)) |
| **Image publishing** | Images are built and pushed to a private container registry (build/publish steps intentionally not documented here) |
| **Image versioning** | SemVer tags (`vMAJOR.MINOR.PATCH`) + `latest` (see [Image versioning policy](#image-versioning-policy)) |
| **Automated testing (CI)** | [.github/workflows/auto_tests.yml](.github/workflows/auto_tests.yml) — runs the pytest suite on every push/PR (see [Continuous integration](#continuous-integration)) |
| **Automated versioning/releases (CI)** | [.github/workflows/tagging.yml](.github/workflows/tagging.yml) — commit-message-driven SemVer tag + GitHub release on every push to `main` |
| **Deployment workflow (CI)** | [.github/workflows/deploy.yml](.github/workflows/deploy.yml) — on every push to `main`, pulls `DATABASE_PATH` from the `dev` GitHub Environment variable and runs `docker compose pull` + `docker compose up -d` |
| **Configuration via GitHub Environments** | The `dev` [GitHub Environment](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment) holds the `DATABASE_PATH` variable used by [deploy.yml](.github/workflows/deploy.yml) |

---

## Architecture

The application is made of two independent services, run as separate containers and talking to each other over a Docker network:

```mermaid
graph LR
    U[User / browser] --> F[frontend<br/>Streamlit :8501]
    F -- HTTP / REST --> B[backend<br/>FastAPI :8000]
    B --> D[(SQLite database)]
```

- **backend** ([FirstApplication/backend](FirstApplication/backend)) — stores people's data in a SQLite database at `DATABASE_PATH` (created automatically on startup). In [docker-compose.yml](FirstApplication/docker-compose.yml) this path lives on a named volume, so data survives container restarts.
- **frontend** ([FirstApplication/frontend](FirstApplication/frontend)) — Streamlit UI, communicates with the backend exclusively through the REST API.

---

## Tech stack

| Layer | Technology | File |
|---|---|---|
| Backend HTTP | **FastAPI** + **Uvicorn** | [backend/main.py](FirstApplication/backend/main.py) |
| Validation | **Pydantic** | [backend/models.py](FirstApplication/backend/models.py) |
| Storage | **SQLite** (stdlib `sqlite3`) | [backend/main.py](FirstApplication/backend/main.py) |
| Frontend | **Streamlit** + **requests** | [frontend/frontend.py](FirstApplication/frontend/frontend.py) |
| Containerization | **Docker** + **Docker Compose** | [backend/Dockerfile](FirstApplication/backend/Dockerfile), [frontend/Dockerfile](FirstApplication/frontend/Dockerfile), [docker-compose.yml](FirstApplication/docker-compose.yml) |

---

## REST API endpoints

| Method | Path | Description |
|---|---|---|
| `POST` | `/people` | Registers a new person on the list |
| `GET` | `/people` | Returns the list of all people |
| `GET` | `/people/{person_id}` | Returns a single person's data |
| `DELETE` | `/people/{person_id}` | Removes a person from the list (requires the correct password in the request body) |

---

## Service addresses and API docs

| Service | Local address | Description |
|---|---|---|
| Frontend | http://localhost:8501 | User interface (Streamlit) |
| Backend (API) | http://localhost:8000 | REST API (FastAPI) |
| API docs (Swagger UI) | http://localhost:8000/docs | Interactive documentation and endpoint testing |
| API docs (ReDoc) | http://localhost:8000/redoc | Alternative documentation view |

---

## Environment variables

| Variable | Service | Default | Description |
|---|---|---|---|
| `API_URL` | frontend | `http://127.0.0.1:8000` | Backend address the frontend sends HTTP requests to. Set to `http://backend:8000` in [docker-compose.yml](FirstApplication/docker-compose.yml) so the frontend can reach the backend by its service name on the Docker network. |
| `DATABASE_PATH` | backend | None; required by Docker Compose | Path to the SQLite database file. The parent directory is created automatically on startup. [docker-compose.yml](FirstApplication/docker-compose.yml) reads it via `${DATABASE_PATH}` substitution, sourced from a local `FirstApplication/.env` file (git-ignored) for local runs, or from the `dev` GitHub Environment variable of the same name in CI (written to `.env` by [deploy.yml](.github/workflows/deploy.yml)). Either way it resolves to `/app/data/app.db`, backed by the `firstapplicationdata` named volume so data survives container restarts. |

The backend's host and port are set directly in [backend/Dockerfile](FirstApplication/backend/Dockerfile) (`uvicorn main:app --host 0.0.0.0 --port 8000`).

---

## Running locally

### With Docker Compose

Create a git-ignored `FirstApplication/.env` file so Compose can resolve `${DATABASE_PATH}` (this mirrors the `DATABASE_PATH` variable stored in the `dev` GitHub Environment, used the same way by [deploy.yml](.github/workflows/deploy.yml) in CI):

```
DATABASE_PATH=/app/data/app.db
```

Then:

```powershell
cd FirstApplication
docker compose up
```

### Without Docker (two terminals)

```powershell
# terminal 1 — backend
cd FirstApplication/backend
pip install -r requirements.txt
uvicorn main:app --reload

# terminal 2 — frontend
cd FirstApplication/frontend
pip install -r requirements.txt
$env:API_URL = "http://127.0.0.1:8000"
streamlit run frontend.py
```

The backend creates its SQLite database at `data/app.db` (relative to the working directory) by default. Set `DATABASE_PATH` before starting the backend to use a different location, e.g. `$env:DATABASE_PATH = "C:\path\to\app.db"`.

---

## Docker / Docker Compose

[docker-compose.yml](FirstApplication/docker-compose.yml) defines two services, `backend` and `frontend`, pulling pre-built images from a private container registry (`ghcr.io/juro-candf/zadania-wdrozeniowe-*`) and exposing ports `8000` and `8501`. The frontend gets `API_URL=http://backend:8000` so it can reach the backend by service name on the Compose network. The backend gets `DATABASE_PATH=/app/data/app.db`, and `/app/data` is backed by the `firstapplicationdata` named volume so the SQLite database survives container restarts and recreations.

Each service has its own multi-stage [Dockerfile](FirstApplication/backend/Dockerfile) based on `dhi.io/python:3.13-debian13-dev`: a `builder` stage creates a virtualenv and installs dependencies from `requirements.txt` with `--require-hashes` (pinned via `pip-compile`), then the final stage copies the venv and application source and runs the app from it.

Build and publish steps (registry path, credentials) are intentionally not documented in this README.

Pulling these images (locally or in CI) requires authenticating to the registry first, even when a package is public, e.g. `docker login ghcr.io -u <github-username>` with a PAT that has `read:packages` scope — otherwise `docker compose pull` can fail with an `error from registry: denied` response.

## Deployment workflow

[.github/workflows/deploy.yml](.github/workflows/deploy.yml) runs on every push to `main`: it writes `DATABASE_PATH=${{ vars.DATABASE_PATH }}` (from the `dev` GitHub Environment) into `FirstApplication/.env`, then runs `docker compose pull` and `docker compose up -d` from `FirstApplication/`.

The workflow currently uses GitHub-hosted `ubuntu-latest`, so its containers and named volume exist only for the duration of the job and are removed when the runner is discarded. It verifies that the stack can pull and start, but it is not a persistent deployment. To deploy an always-on instance, run the same Compose commands on a self-hosted runner or a remote server over SSH.

---

## Image versioning policy

Images are tagged following [Semantic Versioning](https://semver.org/), in the format `vMAJOR.MINOR.PATCH`. The version bump is fully automated by the **Auto Tagging** workflow ([.github/workflows/tagging.yml](.github/workflows/tagging.yml)), which runs on every push to `main` (ignoring commits that only touch `README.md`) and decides the bump from the *commit message prefix*:

- **`feature/...`** — MAJOR bump (breaking/incompatible changes), resets MINOR and PATCH to `0`.
- **`fix/...`** — MINOR bump (new, backward-compatible functionality), resets PATCH to `0`.
- **`hotfix/...`** — PATCH bump (bug fixes, no functional changes).
- Any other commit message — no tag or release is created.

The workflow reads the latest existing `vMAJOR.MINOR.PATCH` tag, computes the new version, pushes the Git tag, and creates a GitHub Release with auto-generated release notes.

Each image is published with two tags: the specific version (e.g. `v1.2.0`) and `latest`, pointing to the newest stable version (used by default in [docker-compose.yml](FirstApplication/docker-compose.yml)). Because the tag is created directly off the commit that lands on `main`, the image version tag reliably traces back to the exact source commit.

---

## Testing

### Automated tests (backend)

The backend has an automated pytest suite in [backend/test_main.py](FirstApplication/backend/test_main.py), driving the API through FastAPI's `TestClient` against an isolated, temporary SQLite database (so tests never touch real data).

Coverage includes:

- **CRUD happy paths** — creating, retrieving, listing, and deleting a person
- **Error responses** — `404` for a missing person (on both `GET` and `DELETE`), `403` for a wrong delete password, `422` for an invalid path parameter type and missing required fields
- **Every `PersonIn` validator** — empty or digit-containing name/surname, a future date of birth, swag level range including boundary values (`500`/`100000` valid, `499`/`100001` invalid), minimum password length (8 characters), password must contain at least one letter and one number, invalid date format
- **Behavioral checks** — correct `age` calculation, IDs increasing across creates, a deleted person disappearing from `GET /people` while others remain, passwords never leaking in single-person or list responses

Dev-only dependencies (`pytest`, `httpx`) are tracked separately from production dependencies in [backend/requirements-dev.in](FirstApplication/backend/requirements-dev.in) / [backend/requirements-dev.txt](FirstApplication/backend/requirements-dev.txt), layered on top of [backend/requirements.txt](FirstApplication/backend/requirements.txt) so shared package versions stay in sync with production.

Install and run the suite with:

```powershell
pip install -r FirstApplication/backend/requirements-dev.txt
pytest FirstApplication/backend/test_main.py -v
```

### Manual verification

1. **Backend via Swagger UI** — after starting the app, open http://localhost:8000/docs and try out the endpoints (`POST /people`, `GET /people`, `GET /people/{id}`, `DELETE /people/{id}`).
2. **Backend via curl**, e.g.:
   ```powershell
   curl -X POST http://localhost:8000/people -H "Content-Type: application/json" -d '{"name":"John","surname":"Smith","date_of_birth":"2000-01-01","swag_level":1000,"password":"pass1234"}'
   curl http://localhost:8000/people
   ```
3. **Frontend end-to-end** — open http://localhost:8501, add a person through the form, verify they appear on the list, then remove them using the password set at registration.
4. **Data validation** — verify the backend rejects invalid data (e.g. `swag_level` below 500, a future date of birth, a password shorter than 8 characters or missing a letter/number) with a `422` status code.

---

## Continuous integration

Three GitHub Actions workflows in [.github/workflows](.github/workflows) automate testing, releases, and deployment:

| Workflow | Trigger | What it does |
|---|---|---|
| **Auto Tests** ([auto_tests.yml](.github/workflows/auto_tests.yml)) | Push or pull request on any branch | Installs [backend/requirements.txt](FirstApplication/backend/requirements.txt) and [backend/requirements-dev.txt](FirstApplication/backend/requirements-dev.txt) on Python 3.13 (matching the Docker images), then runs `pytest` against [backend/test_main.py](FirstApplication/backend/test_main.py) from `FirstApplication/backend`, producing a JUnit XML report that is printed as a final step. |
| **Auto Tagging** ([tagging.yml](.github/workflows/tagging.yml)) | Push to `main` (ignoring README-only commits) | Bumps and pushes a new SemVer Git tag based on the commit message prefix and creates a matching GitHub Release — see [Image versioning policy](#image-versioning-policy) |
| **Deploy** ([deploy.yml](.github/workflows/deploy.yml)) | Push to `main` (ignoring README-only commits) | Runs with `environment: dev`; writes the `DATABASE_PATH` environment variable into `FirstApplication/.env`, then runs `docker compose pull` and `docker compose up -d` to redeploy with the latest published images |

---

## Repository structure

```
.github/
├── workflows/
│   ├── auto_tests.yml       # runs pytest on push/PR (Python 3.13)
│   ├── tagging.yml          # commit-prefix-driven SemVer tagging + GitHub release
│   └── deploy.yml           # pulls DATABASE_PATH from the "dev" environment, docker compose pull + up -d on push to main
FirstApplication/
├── docker-compose.yml       # backend + frontend services, ports, API_URL, DATABASE_PATH, data volume
├── .env                     # git-ignored; local DATABASE_PATH used by docker compose (mirrors the "dev" environment variable)
├── backend/
│   ├── Dockerfile           # multi-stage FastAPI + Uvicorn image (dhi.io/python base)
│   ├── .dockerignore        # excludes tests, dev-only deps, caches from the build context
│   ├── main.py              # API endpoints, password hashing, SQLite storage
│   ├── models.py            # Pydantic schemas + validators
│   ├── test_main.py         # pytest suite (API + validation coverage)
│   ├── requirements.txt
│   ├── requirements-dev.in  # dev-only deps (pytest, httpx) on top of requirements.in
│   └── requirements-dev.txt
└── frontend/
    ├── Dockerfile           # multi-stage Streamlit image (dhi.io/python base)
    ├── .dockerignore        # excludes dev-only files, caches from the build context
    ├── frontend.py          # UI: registration form + people table
    └── requirements.txt
```
