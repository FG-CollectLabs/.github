# Grading Predictor — TODO

> **Task IDs are stable.** Never renumber. New tasks get the next free ID.
>
> **Status legend:** `[ ]` open · `[~]` claimed/in-progress · `[x]` done · `[!]` blocked · `[-]` cancelled

---

## 1. Backend — v0.1

- [x] T-001 Scaffold repo structure: cmd/api, internal/{config,db,httpx,predictor}, migrations, queries, Dockerfile, go.mod, sqlc.yaml
- [x] T-002 Write 0001_init.sql migration: cards, certifications, cert_images, inspections tables
- [ ] T-003 Generate sqlc types for all tables
- [ ] T-004 Implement `GET /v1/cards` + `POST /v1/cards`
- [ ] T-005 Implement `GET /v1/cards/{id}` with cert list
- [ ] T-006 Implement `POST /v1/certs` + `PATCH /v1/certs/{id}/grade`
- [ ] T-007 Implement `GET /v1/certs/{id}/inspections` + `POST /v1/certs/{id}/inspections`
- [ ] T-008 Implement `POST /v1/certs/{id}/images` — multipart upload to GCS
- [ ] T-009 Provision Proxmox PG instance + run migrations
- [ ] T-010 Provision GCS bucket `fg-grading-predictor`
- [ ] T-011 Dockerfile + docker run on LXC

## 2. Frontend — v0.1

- [x] T-012 Scaffold repo: Vite + React + TS + Tailwind v3, package.json, vite.config, tsconfig
- [x] T-013 Wire React Router: CardList `/`, CardDetail `/cards/:id`, NewCert `/certs/new`
- [ ] T-014 CardList: grid of cards with game/set/name + PSA 10/9 count badges
- [ ] T-015 CardDetail: cert list table + defect fields per row
- [ ] T-016 DefectBuckets: group certs by profile, show grade distribution per bucket
- [ ] T-017 NewCert form: card selector/creator, cert number, image upload, inspection fields
- [ ] T-018 API wiring: connect all pages to backend endpoints
- [ ] T-019 Deploy to GH Pages

## 3. Hub

- [x] T-020 Add grading-predictor card to hub index.html (In Planning section)
- [x] T-021 Add roadmap card to Releases & Roadmap tab
- [x] T-022 Add entry to Data Flow diagram + Database Map table

## 4. v0.2 — Stats

- [ ] T-023 `GET /v1/cards/{id}/stats` — SQL GROUP BY defect profile + grade_received
- [ ] T-024 Frontend: render stats as visual bucket cards with hit-rate percentage
- [ ] T-025 Prediction input: enter defect profile for a new card, show matching bucket

## 5. v0.3 — Auto Centering

- [ ] T-026 Add `POST /v1/certs/{id}/inspections` to slab-cracker-backend's analysis completion flow
- [ ] T-027 Frontend: detect pre-filled centering, show source badge on inspection rows
