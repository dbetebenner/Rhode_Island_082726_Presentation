### 01_generate_summary.R
###
### Loads the (large) Rhode Island SGP LONG data ONCE and writes a compact
### summary cache (summary/ri_sgp_summary.rds) consumed by the Quarto deck.
### The deck never touches the LONG file, so re-rendering is fast.
###
### Re-run after a data refresh:
###   Rscript R/01_generate_summary.R            # skips if cache is up to date
###   Rscript R/01_generate_summary.R --force    # always rebuild
###
### Config (data path, analysis year) can be overridden with env vars:
###   RI_LONG_DATA=/path/to/LONG.Rdata RI_ANALYSIS_YEAR=2025_2026 Rscript ...

suppressPackageStartupMessages({
  library(data.table)
})

## ---------------------------------------------------------------------------
## Configuration
## ---------------------------------------------------------------------------

this_dir <- tryCatch({
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- sub("^--file=", "", args[grep("^--file=", args)])
  if (length(file_arg)) dirname(normalizePath(file_arg)) else getwd()
}, error = function(e) getwd())

PROJECT_ROOT <- normalizePath(file.path(this_dir, ".."))

LONG_DATA_PATH <- Sys.getenv(
  "RI_LONG_DATA",
  "/Users/conet/GitHub/CenterForAssessment/Rhode_Island/master/Data/Rhode_Island_SGP_LONG_Data.Rdata"
)
ANALYSIS_YEAR <- Sys.getenv("RI_ANALYSIS_YEAR", "")  # "" => use latest year in data
CACHE_PATH    <- file.path(PROJECT_ROOT, "summary", "ri_sgp_summary.rds")

FORCE <- any(commandArgs(trailingOnly = TRUE) %in% c("--force", "-f"))

source(file.path(this_dir, "00_helpers.R"))

## ---------------------------------------------------------------------------
## Idempotency: skip if cache is newer than the source LONG file
## ---------------------------------------------------------------------------

if (!file.exists(LONG_DATA_PATH)) {
  stop("LONG data file not found: ", LONG_DATA_PATH)
}

if (!FORCE && file.exists(CACHE_PATH) &&
    file.mtime(CACHE_PATH) > file.mtime(LONG_DATA_PATH)) {
  message("Cache is up to date (", CACHE_PATH, "). Use --force to rebuild.")
  quit(save = "no", status = 0)
}

## ---------------------------------------------------------------------------
## Load LONG data (once)
## ---------------------------------------------------------------------------

t0 <- Sys.time()
message("Loading LONG data: ", LONG_DATA_PATH)
load_env <- new.env()
load(LONG_DATA_PATH, envir = load_env)
long_obj_name <- ls(load_env)[1]
d <- get(long_obj_name, envir = load_env)
setDT(d)
message("  loaded ", format(nrow(d), big.mark = ","), " rows in ",
        round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 1), "s")

if (!nzchar(ANALYSIS_YEAR)) {
  ANALYSIS_YEAR <- max(as.character(d$YEAR), na.rm = TRUE)
}
message("Analysis year: ", ANALYSIS_YEAR)

## ---------------------------------------------------------------------------
## Prepare a trimmed working table (valid, growth content areas, recoded)
## ---------------------------------------------------------------------------

g <- d[VALID_CASE == "VALID_CASE" & CONTENT_AREA %in% GROWTH_CONTENT_AREAS]

## Recode subgroup labels
g[, ETHNICITY := recode_ethnicity(ETHNICITY)]
g[, IEP_STATUS := clean_iep(IEP_STATUS)]
g[, GENDER := clean_gender(GENDER)]
g[, HIGH_NEED_STATUS := fcase(
  grepl("Below 25", HIGH_NEED_STATUS), "Prior Achievement < 25th %ile",
  grepl("Above 75", HIGH_NEED_STATUS), "Prior Achievement > 75th %ile",
  default = NA_character_
)]

## Convenience display columns
g[, ASSESSMENT := assessment_of(CONTENT_AREA)]
g[, SUBJECT := pretty_subject(CONTENT_AREA)]
g[, GRADE_LABEL := pretty_grade(GRADE, CONTENT_AREA)]

## ---------------------------------------------------------------------------
## overall: cohort + baseline mean/median/N by content x grade x year
## ---------------------------------------------------------------------------

overall <- summarise_sgp(g, by = c("CONTENT_AREA", "SUBJECT", "ASSESSMENT",
                                   "GRADE", "GRADE_LABEL", "YEAR"))
overall[, YEAR_LABEL := pretty_year(YEAR)]
setorder(overall, ASSESSMENT, SUBJECT, GRADE, YEAR)

## ---------------------------------------------------------------------------
## levels: Low/Typical/High distribution, cohort + baseline
## ---------------------------------------------------------------------------

lev_cohort <- summarise_levels(
  g[!is.na(SGP_LEVEL)], "SGP_LEVEL",
  by = c("CONTENT_AREA", "SUBJECT", "ASSESSMENT", "GRADE", "GRADE_LABEL", "YEAR")
)
lev_cohort[, NORM := "Cohort"]

lev_baseline <- summarise_levels(
  g[!is.na(SGP_LEVEL_BASELINE)], "SGP_LEVEL_BASELINE",
  by = c("CONTENT_AREA", "SUBJECT", "ASSESSMENT", "GRADE", "GRADE_LABEL", "YEAR")
)
lev_baseline[, NORM := "Baseline"]

levels_dt <- rbind(lev_cohort, lev_baseline)
levels_dt[, YEAR_LABEL := pretty_year(YEAR)]
levels_dt[, LEVEL := factor(LEVEL, levels = c("Low", "Typical", "High"))]

## ---------------------------------------------------------------------------
## subgroups: analysis-year cohort + baseline mean/median/N by dimension
## ---------------------------------------------------------------------------

gy <- g[YEAR == ANALYSIS_YEAR]

build_subgroup <- function(dim_label, col) {
  x <- copy(gy)
  x[, GROUP := as.character(get(col))]
  x <- x[!is.na(GROUP)]
  out <- summarise_sgp(x, by = c("ASSESSMENT", "SUBJECT", "GRADE_LABEL", "GROUP"))
  out[, DIMENSION := dim_label]
  out
}

subgroups <- rbindlist(
  Map(build_subgroup, names(SUBGROUP_DIMENSIONS), unlist(SUBGROUP_DIMENSIONS)),
  use.names = TRUE
)
setcolorder(subgroups, c("DIMENSION", "GROUP", "ASSESSMENT", "SUBJECT", "GRADE_LABEL"))

## Pooled across grades (true medians), by assessment x subject x dimension x
## group — the clean single-number equity view used on the summary equity slide.
build_subgroup_pooled <- function(dim_label, col) {
  x <- copy(gy)
  x[, GROUP := as.character(get(col))]
  x <- x[!is.na(GROUP)]
  out <- summarise_sgp(x, by = c("ASSESSMENT", "SUBJECT", "GROUP"))
  out[, DIMENSION := dim_label]
  out
}
subgroups_pooled <- rbindlist(
  Map(build_subgroup_pooled, names(SUBGROUP_DIMENSIONS), unlist(SUBGROUP_DIMENSIONS)),
  use.names = TRUE
)
setcolorder(subgroups_pooled, c("DIMENSION", "GROUP", "ASSESSMENT", "SUBJECT"))

## ---------------------------------------------------------------------------
## targets: catch-up/keep-up & move-up/stay-up attainment (analysis year)
## ---------------------------------------------------------------------------

## Attainment rate = Yes / (Yes + No) within each aspiration group.
target_rates <- function(dt, status_col, by) {
  x <- dt[!is.na(get(status_col)), .(status = get(status_col)), by = by]
  x[, aspiration := sub(":.*$", "", status)]        # "Catch Up" / "Keep Up"
  x[, attained := grepl("Yes$", status)]
  x[, .(n = .N, attained = sum(attained)),
    by = c(by, "aspiration")][, rate := 100 * attained / n][]
}

cuku_overall <- target_rates(gy, "CATCH_UP_KEEP_UP_STATUS_3_YEAR",
                             by = c("ASSESSMENT", "SUBJECT", "GRADE_LABEL"))
cuku_overall[, `:=`(NORM = "Cohort", METRIC = "Catch Up / Keep Up")]

cuku_baseline <- target_rates(gy, "CATCH_UP_KEEP_UP_STATUS_BASELINE_3_YEAR",
                              by = c("ASSESSMENT", "SUBJECT", "GRADE_LABEL"))
cuku_baseline[, `:=`(NORM = "Baseline", METRIC = "Catch Up / Keep Up")]

musu_overall <- target_rates(gy, "MOVE_UP_STAY_UP_STATUS_3_YEAR",
                             by = c("ASSESSMENT", "SUBJECT", "GRADE_LABEL"))
musu_overall[, `:=`(NORM = "Cohort", METRIC = "Move Up / Stay Up")]

targets <- rbind(cuku_overall, cuku_baseline, musu_overall, use.names = TRUE, fill = TRUE)

## Catch-up/keep-up by high-need status (equity contrast)
cuku_highneed <- target_rates(
  gy[!is.na(HIGH_NEED_STATUS)], "CATCH_UP_KEEP_UP_STATUS_3_YEAR",
  by = c("ASSESSMENT", "HIGH_NEED_STATUS")
)
cuku_highneed[, `:=`(NORM = "Cohort", METRIC = "Catch Up / Keep Up")]

## ---------------------------------------------------------------------------
## meta
## ---------------------------------------------------------------------------

n_tested <- gy[, .(n_tested = .N,
                   n_growth_cohort = sum(!is.na(SGP)),
                   n_growth_baseline = sum(!is.na(SGP_BASELINE))),
               by = .(ASSESSMENT, SUBJECT, GRADE_LABEL)]

sgp_version <- tryCatch(as.character(utils::packageVersion("SGP")),
                        error = function(e) NA_character_)

meta <- list(
  analysis_year   = ANALYSIS_YEAR,
  analysis_year_label = pretty_year(ANALYSIS_YEAR),
  years_available = sort(unique(as.character(g$YEAR))),
  content_areas   = GROWTH_CONTENT_AREAS,
  ricas_grades    = sort(unique(g[ASSESSMENT == "RICAS"]$GRADE)),
  n_tested        = n_tested,
  n_tested_total  = nrow(gy),
  n_growth_cohort_total   = sum(!is.na(gy$SGP)),
  n_growth_baseline_total = sum(!is.na(gy$SGP_BASELINE)),
  sgp_package_version = sgp_version,
  source_file     = LONG_DATA_PATH,
  source_mtime    = file.mtime(LONG_DATA_PATH),
  generated_at    = Sys.time()
)

## ---------------------------------------------------------------------------
## Write cache
## ---------------------------------------------------------------------------

summary_list <- list(
  meta          = meta,
  overall       = overall,
  levels        = levels_dt,
  subgroups     = subgroups,
  subgroups_pooled = subgroups_pooled,
  targets       = targets,
  targets_highneed = cuku_highneed
)

dir.create(dirname(CACHE_PATH), showWarnings = FALSE, recursive = TRUE)
saveRDS(summary_list, CACHE_PATH)

message("Wrote cache: ", CACHE_PATH,
        " (", round(file.size(CACHE_PATH) / 1024, 1), " KB)")
message("Done in ", round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 1), "s")
