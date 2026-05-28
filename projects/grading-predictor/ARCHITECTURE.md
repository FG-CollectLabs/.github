# Grading Predictor — Architecture

> **Status:** Planning / Scaffold
> **Codename:** grading-predictor
> **Goal:** Personal card-grading prediction database. Log PSA certs with front/back scan images and manual defect observations (centering, surface, corners, edges). Build up enough data per card to calculate empirical probability of PSA 9 vs 10 given a defect profile — like counting cards, but for grading.

## North-star feature set

1. **Card browser** — navigate cards like the market tracker; each card shows grade distribution at a glance
2. **Cert entry** — log a new cert number with front/back scan images (stored in GCS), then annotate defects manually
3. **Defect buckets** — card detail page groups logged certs by defect profile and shows how many came back PSA 9 vs PSA 10
4. **Append-only** — every cert and inspection is immutable; nothing gets deleted, the dataset only grows
5. **Auto-centering (future)** — centering values can be prefilled from slab-cracker analysis output; `source` field on inspections distinguishes `manual` vs `auto`

## System diagram

```
grading-predictor-frontend  (Vite/React/TS · GH Pages)
  │  Bearer token on writes
  ▼
grading-predictor-backend   (Go · :8084 · grading-api.futuregadgetlabs.com)
  ├── PostgreSQL  192.168.86.???  grading_predictor DB
  └── GCS  fg-grading-predictor bucket  (cert scan images)

Future input:
  slab-cracker-backend ──▶  POST /v1/certs/{id}/inspections  (auto centering)
```

## Repos

| Repo | Lang | Status | Role |
|------|------|--------|------|
| `FG-CollectLabs/grading-predictor-backend` | Go | scaffold | REST API, DB, GCS image upload |
| `FG-CollectLabs/grading-predictor-frontend` | Vite/React/TS | scaffold | Card browser + cert entry UI |

## Repo structure

```
grading-predictor-backend/
├── cmd/api/main.go
├── internal/
│   ├── config/        env var loading
│   ├── db/            pgxpool wrapper
│   ├── httpx/         CORS, logging, recovery, BearerAuth, WriteJSON
│   └── predictor/     handlers + query helpers
├── migrations/        Goose SQL migrations
├── queries/           sqlc SQL query files
├── Dockerfile
├── go.mod
└── sqlc.yaml

grading-predictor-frontend/
├── src/
│   ├── App.tsx        router root
│   ├── api.ts         typed fetch wrappers
│   ├── types.ts       shared TS types
│   └── pages/
│       ├── CardList.tsx    browse + search
│       ├── CardDetail.tsx  defect buckets + cert list
│       └── NewCert.tsx     cert entry form
├── index.html
├── package.json
├── vite.config.ts
└── tsconfig.json
```

## Storage ownership

| Store | Owner | Contents |
|-------|-------|----------|
| PostgreSQL `grading_predictor` | grading-predictor-backend | cards, certifications, cert_images, inspections |
| GCS `fg-grading-predictor` | grading-predictor-backend | cert scan images (front/back) |

## Storage map

### PostgreSQL — `grading_predictor`

```sql
cards (id, game, set_code, set_name, card_name, card_number, created_at)
  UNIQUE (game, set_code, card_number)

certifications (id, card_id, cert_number, grader, grade_received, graded_at, notes, created_at)
  UNIQUE (cert_number)

cert_images (id, cert_id, side [front|back], gcs_path, created_at)

inspections (
  id, cert_id,
  centering_front_lr, centering_front_tb,   -- % of border on left/top side
  centering_back_lr, centering_back_tb,
  surface_front, surface_back,               -- clean | light_scratch | heavy_scratch | print_line | print_dot
  corner_tl, corner_tr, corner_bl, corner_br, -- sharp | light_wear | heavy_wear
  edge_top, edge_bottom, edge_left, edge_right, -- clean | light_wear | heavy_wear | nick
  notes, source [manual|auto], created_at
)
```

### GCS — `fg-grading-predictor`

```
{cert_number}/front.jpg
{cert_number}/back.jpg
```

## Key architectural decisions

- **Append-only** — no UPDATE/DELETE on certs or inspections; grade_received is the only mutable field on certifications (set once when graded result comes back)
- **Manual first, auto later** — `source` field on inspections allows slab-cracker to POST auto-centering without changing the schema
- **Defect buckets are client-side for now** — the frontend groups certs by defect profile; a server-side `/v1/cards/{id}/stats` aggregation endpoint can be added once the data model is validated
- **No auth framework** — same Bearer ADMIN_API_TOKEN pattern as slab-cracker; single personal-use tool

## Data flow: Prediction loop

```
1. Buy raw card
2. POST /v1/certs — log cert number + card_id
3. POST /v1/certs/{id}/images — upload front + back scans
4. POST /v1/certs/{id}/inspections — annotate defects manually
5. Send card to PSA
6. PATCH /v1/certs/{id}/grade — record grade_received
7. GET /v1/cards/{id}/certs — frontend shows grade distribution per defect bucket
8. Next card: compare defect profile against historical → read predicted grade probability
```
