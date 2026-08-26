# Rhode Island 2026 SGP Analyses — RIDE TAC Presentation

A reveal.js (Quarto) presentation of Rhode Island's 2026 Student Growth
Percentile (SGP) results — RICAS (ELA/Math, grades 4–8) and SAT (grade 11) —
for the RIDE Technical Advisory Committee. Covers cohort- and baseline-referenced
growth, goodness of fit, multi-year trends (pandemic recovery / scale drift),
growth by student group, and catch-up/keep-up target attainment.

## Present it

Open **`docs/index.html`** in any browser (self-contained, works offline). The
deck renders to `docs/index.html` so GitHub Pages can serve it directly — set the
Pages source to **Deploy from a branch → `/docs`**.

- **`S`** — speaker view (per-slide notes + timer)
- **`F`** — fullscreen · **`O`** — overview · arrows / space to advance
- Click any goodness-of-fit plot to enlarge it.

## The pipeline (why it re-renders fast, and re-runs cleanly)

The student-level LONG data file is large (~70 MB, 1.6 M rows). Loading it every
time the deck is edited would be slow, so the deck **never** reads it directly.
Instead a one-time R step distills it into a compact (~17 KB) cached summary that
the deck consumes.

```
Rhode_Island_SGP_LONG_Data.Rdata ─► R/01_generate_summary.R ─► summary/ri_sgp_summary.rds ─┐
Goodness_of_Fit/*.svg            ─► R/02_collect_figures.R  ─► Figures/gof/*.svg          ─┤
                                                                                           ▼
                                                Rhode_Island_2026_SGP_Results.qmd ─► docs/index.html
```

### Build

```bash
./render.sh            # cache rebuilt only if the LONG data is newer; then render
./render.sh --force    # force cache rebuild, then figures + render
```

or with `make`:

```bash
make            # incremental build
make force      # force full rebuild
make cache      # summary cache only
make figures    # vendor goodness-of-fit SVGs only
make render     # render the deck only
```

### Re-running with revised data

When RIDE supplies a revised LONG file, just rebuild — every number, table, and
trend in the deck refreshes automatically:

```bash
./render.sh --force
```

Data / figure locations default to the `CenterForAssessment/Rhode_Island`
working copy and can be overridden:

```bash
RI_LONG_DATA="/path/to/Rhode_Island_SGP_LONG_Data.Rdata" \
RI_GOF_ROOT="/path/to/Goodness_of_Fit" \
RI_DATA_RECEIVED="August 25, 2026" \
./render.sh --force
```

## What the cache contains

`summary/ri_sgp_summary.rds` is a named list produced by
[`R/01_generate_summary.R`](R/01_generate_summary.R):

| Element | Contents |
|---|---|
| `meta` | Run date, source-file mtime, `SGP` package version, N tested / with growth, years available |
| `overall` | mean/median/N of cohort & baseline SGP by content area × grade × year |
| `levels` | Low/Typical/High distribution (cohort & baseline) by content × grade × year |
| `subgroups` | Analysis-year subgroup means/medians by content × grade × group |
| `subgroups_pooled` | Analysis-year subgroup means/medians pooled across grades (true medians) |
| `targets` | Catch-up/keep-up & move-up/stay-up attainment by grade |
| `targets_highneed` | Catch-up/keep-up attainment by prior-achievement (high-need) status |

## Files

```
Rhode_Island_2026_SGP_Results.qmd   deck source (reads the cache; renders to docs/index.html)
R/00_helpers.R                      recodes, labels, mean/median/N formatting
R/01_generate_summary.R             LONG data ─► summary/ri_sgp_summary.rds (idempotent)
R/02_collect_figures.R              Goodness_of_Fit ─► Figures/gof/*.svg (clean-named)
summary/ri_sgp_summary.rds          the compact cached summary
Figures/gof/                        vendored goodness-of-fit SVGs + manifest.csv
render.sh · Makefile                pipeline orchestration
docs/index.html                     rendered deck (GitHub Pages entry point)
styles/                             reveal.js theme + figure lightbox
assets/fonts/                       math font
```

## Requirements

- [Quarto](https://quarto.org) ≥ 1.4
- R with `data.table`, `ggplot2`, `scales`, and the `SGP` package (for the
  reported package version)
