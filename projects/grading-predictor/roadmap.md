# Grading Predictor — Release Roadmap

High-level milestones. Granular task tracking lives in [TODO.md](./TODO.md).

---

## v0.1 — Core Data Entry

Foundation: log certs, upload scans, annotate defects, record grades.

- Backend scaffold: cards, certifications, cert_images, inspections tables
- `POST /v1/cards`, `GET /v1/cards`, `GET /v1/cards/{id}`
- `POST /v1/certs`, `PATCH /v1/certs/{id}/grade`
- `POST /v1/certs/{id}/images` — multipart upload → GCS
- `POST /v1/certs/{id}/inspections` — manual defect annotation
- Frontend: card browser, card detail page, new cert form with inspection entry
- GCS bucket `fg-grading-predictor` provisioned

---

## v0.2 — Defect Bucket Stats

Turn the raw data into useful predictions.

- **Server-side aggregation**: `GET /v1/cards/{id}/stats` groups certs by defect profile, returns grade distribution counts
- **Frontend bucket UI**: card detail shows visual breakdown — "55/45 centering + clean surface: 12×PSA10, 2×PSA9"
- **Prediction surface**: given a new card's defect profile, show matching bucket's historical hit rate
- **Card search + filter** by game, set, card name

---

## v0.3 — Auto Centering Input

Connect slab-cracker output as an automated inspection source.

- **Slab-cracker integration**: slab-cracker-backend POST to `/v1/certs/{id}/inspections` with `source: auto` when centering analysis completes
- **Prefill UI**: new cert form prefills centering from slab-cracker if cert_number is recognized
- **Source indicator**: inspection list distinguishes manual vs auto entries

---

## v0.4 — Deploy & Tunnel

Make it accessible from anywhere.

- Provision new Proxmox LXC or reuse existing PG instance
- `grading-api.futuregadgetlabs.com` Cloudflare tunnel
- GitHub Pages deploy for frontend
- Health check added to hub

---

## v0.5 — Bulk Backfill

Seed the dataset faster.

- **CSV import**: bulk import historical cert data (cert number, grade, defect fields as columns)
- **Batch inspection**: apply same defect profile to multiple certs of the same card in one action
- **Export**: dump all inspections for a card as CSV for external analysis
