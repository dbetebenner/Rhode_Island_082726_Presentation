# Rhode Island 2026 SGP Analyses — RIDE TAC Presentation

A reveal.js (Quarto) presentation of Rhode Island's 2026 Student Growth
Percentile (SGP) results — RICAS (ELA/Math, grades 4–8) and SAT (grade 11) —
for the RIDE Technical Advisory Committee. Covers cohort- and baseline-referenced
growth, goodness of fit, multi-year trends (pandemic recovery / scale drift),
growth by student group, and catch-up/keep-up target attainment.

**Revision 2 (August 27, 2026)** incorporates written feedback from the TAC. The
deck is a living document: because every number derives from the analysis
pipeline, validated feedback that changes an analysis changes the deck by
rebuilding it rather than editing it. The substantive changes in this revision:

- Baseline-referenced growth is now read alongside **cross-sectional results
  from the norm period**, following Ho (2009). This reverses the reading of the
  mathematics trend: status has recovered to pre-pandemic levels, so the falling
  baseline SGP is rebound growth fading rather than a decline in learning. ELA,
  which is down on both measures, becomes the headline concern.
- **Grade-11 baseline SGPs are recommended for withholding** from public
  reporting. They contradict every cross-sectional measurement of the same
  cohort and pile up at the ceiling of the distribution.
- The goodness-of-fit section is reframed as **model fit and conditional
  coverage**, stating what the plots do and do not diagnose given a discrete scale.
- Catch-up/keep-up now reports its **target horizon** (three years at grade 4
  down to none at grade 8), denominators, and Wilson intervals.
- Standard deviations accompany every group mean.

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
| `proficiency` | Percent proficient by content area × grade × year (cross-sectional status) |
| `xsec` | Distributional comparison against the baseline norm year: `auc` = P(Y<sub>current</sub> > Y<sub>norm</sub>) and Ho's scale-invariant `V` |
| `pp` | Probability–probability curve coordinates, analysis year vs the norm year |
| `sgp_distribution` | Full cohort and baseline SGP distributions by decile |

`xsec` and `pp` implement the nonparametric comparison of Ho, A. D. (2009),
*A nonparametric framework for comparing trends and gaps across tests*,
Journal of Educational and Behavioral Statistics, 34, 201–228. Note that `auc`
is exactly the mean **unconditional** baseline percentile — the baseline SGP with
the prior-score conditioning removed — which is what makes the conditional and
cross-sectional series directly comparable.

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

## The PSTricks schematic

`Figures/PSTricks/sgp_cdf_identity.tex` draws the figure on the "One statistic,
with and without conditioning" slide, which shows that the cross-sectional
comparison is the baseline SGP with the prior-score conditioning removed. Build
it with:

```bash
cd Figures/PSTricks && Rscript build_pstricks.R
```

The chain follows the house pattern (`latex` → `dvips` → `gs` → `pdfcrop` →
`pdf2svg`), writing `Figures/sgp_cdf_identity.{pdf,svg}`. Four things about it
are load-bearing and easy to trip over again:

- `algebraic` plotting comes from **pstricks-add**, not `pst-plot`. Without it
  the expression is passed through as raw PostScript and the page silently
  renders blank.
- `pst-algparser` maps `exp()` onto PostScript's *two-operand power* operator,
  so the natural exponential is **`EXP()`**; its trig functions take **radians**.
- The `pspicture` box reserves its own vertical space — adding `\vspace` pushes
  the figure off the page.
- `opacity` does not survive `dvips` → `gs pdfwrite`, so translucent fills are
  written as explicit pale colours.

Because `dvips -E` cannot measure PostScript specials it returns a degenerate
BoundingBox, so the figure is drawn on a generous canvas and cropped to its real
ink by `pdfcrop` rather than by a hard-coded box. A PostScript error still yields
a valid but *blank* PDF, so the build treats any Ghostscript diagnostic as a
failure instead of shipping an empty figure.

## Requirements

- [Quarto](https://quarto.org) ≥ 1.4
- R with `data.table`, `ggplot2`, `scales`, and the `SGP` package (for the
  reported package version)
- For the PSTricks figure only: a TeX distribution providing `latex`, `dvips`,
  `pstricks-add` and `pdfcrop`, plus `ghostscript` and `pdf2svg`
