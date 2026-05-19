# hOCG EV Calculator — Architecture

## What it is

Single-file Python CLI (`hocg_ev.py`) that computes expected value for opening
hololive Official Card Game sealed product. Set-agnostic: all set data, prices,
costs, and pull-rate assumptions live in a YAML config file.

## Repo

`FG-CollectLabs/hocg-ev-calculator`

## Why separate from ev-calculator

`ev-calculator` is a Go + Hugo service priced against market-tracker HTTP data,
focused on MTG Commander precon EV. This tool is:
- A standalone Python CLI (no server, no live data fetching)
- hOCG-specific rarity system (C/U/R/RR/OSR + S/SR/UR/OUR/SEC)
- Config-file driven — user supplies prices manually from TCGPlayer / TCGRepublic

## Pack model

```
8 cards per pack
├── Slot 1: rare slot   (1×) — R baseline; upgrades to RR / OSR / UR / OUR / SEC
├── Slot 2: foil slot   (1×) — S baseline; upgrades to SR
└── Slots 3-8: filler   (6×) — C / U mix
```

Pull rates are community estimates (publisher does not disclose official rates).
Two scenarios: optimistic and pessimistic.

## EV math

```
EV_pack = Σ(P(rarity) × avg_price)  across all slots
EV_box  = packs_per_box × EV_pack
EV_case = boxes_per_case × EV_box
EV_mcase = master_case_multiplier × EV_case

Net EV at tier = Gross EV - cost
```

P(at least one X in N packs) uses binomial independence:
```
P = 1 - (1 - p_per_pack)^N
```

Sensitivity: solves for the SEC pull rate that makes net EV = 0.

## Output

- ASCII table per scenario: pack breakdown, tier summary, expected counts,
  P(at-least-one), SEC breakeven rate
- Optional JSON dump (`--json`) for downstream use

## Deps

- stdlib only + `pyyaml`

## Config files

`examples/` — one YAML per set. Ship with BP01 EN structural data.
User fills in prices and costs before running.

## Potential V2 additions

- TCGPlayer price fetch script (separate helper, not in main tool)
- Per-card price weighting within a rarity (instead of single avg)
- JP config variants (10 boxes/case instead of 12)
- Pull-rate override flags for quick sensitivity sweeps
