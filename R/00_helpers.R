### 00_helpers.R
### Shared recode/label/format helpers for the Rhode Island 2026 SGP
### presentation pipeline. Sourced by 01_generate_summary.R and (for the
### formatting helpers) by the Quarto deck.

suppressPackageStartupMessages({
  library(data.table)
})

## ---------------------------------------------------------------------------
## Analysis constants
## ---------------------------------------------------------------------------

## RICAS = grades 4-8 ELA/Math (grade 3 has no prior, so no growth).
## SAT   = grade 11 EOCT (ELA_SAT / MATHEMATICS_SAT), single PSAT-10 prior.
RICAS_CONTENT_AREAS <- c("ELA", "MATHEMATICS")
SAT_CONTENT_AREAS   <- c("ELA_SAT", "MATHEMATICS_SAT")
GROWTH_CONTENT_AREAS <- c(RICAS_CONTENT_AREAS, SAT_CONTENT_AREAS)

## Subgroup dimensions surfaced in the equity section. Each entry names the
## source column; recoding (if any) is applied in prepare_growth_data().
SUBGROUP_DIMENSIONS <- list(
  Gender                  = "GENDER",
  `Race/Ethnicity`        = "ETHNICITY",
  `English Learner`       = "ELL_STATUS",
  `Students w/ Disability` = "IEP_STATUS",
  `Economically Disadv.`  = "FREE_REDUCED_LUNCH_STATUS",
  `High Need`             = "HIGH_NEED_STATUS"
)

## ---------------------------------------------------------------------------
## Recodes (the LONG file carries a few duplicate/stray category labels)
## ---------------------------------------------------------------------------

recode_ethnicity <- function(x) {
  x <- as.character(x)
  x[x == "American Indian or Alaskan Native"] <- "American Indian or Alaska Native"
  x[x == "Multiple Ethnicities Reported"]     <- "Two or More Races"
  x[x %in% c("No Primary Race/Ethnicity Reported", "Other")] <- NA_character_
  x
}

clean_iep <- function(x) {
  x <- as.character(x)
  x[x == "Students with Disabilities (IEP)"]       <- "Students with Disabilities (IEP)"
  x[x == "Students without Disabilities (Non-IEP)"] <- "Students without Disabilities (Non-IEP)"
  x[x == "Students with 504 Plan"]                 <- "Students with 504 Plan"
  x[!x %in% c("Students with Disabilities (IEP)",
              "Students without Disabilities (Non-IEP)",
              "Students with 504 Plan")] <- NA_character_
  x
}

clean_gender <- function(x) {
  x <- as.character(x)
  x[!x %in% c("Female", "Male")] <- NA_character_
  x
}

## ---------------------------------------------------------------------------
## Pretty labels
## ---------------------------------------------------------------------------

assessment_of <- function(content_area) {
  fifelse(content_area %in% SAT_CONTENT_AREAS, "SAT", "RICAS")
}

pretty_subject <- function(content_area) {
  data.table::fcase(
    content_area %in% c("ELA", "ELA_SAT"), "ELA",
    content_area %in% c("MATHEMATICS", "MATHEMATICS_SAT"), "Mathematics",
    default = content_area
  )
}

## Display grade: SAT EOCT is presented as "11 (SAT)" as in prior decks.
pretty_grade <- function(grade, content_area) {
  fifelse(content_area %in% SAT_CONTENT_AREAS, "11 (SAT)", as.character(grade))
}

pretty_year <- function(year) {
  ## "2025_2026" -> "2026" (spring administration year)
  sub("^[0-9]{4}_", "", as.character(year))
}

## ---------------------------------------------------------------------------
## Formatting for the "mean/median/N" cells used throughout the deck
## ---------------------------------------------------------------------------

fmt_count <- function(n) formatC(n, format = "d", big.mark = ",")

fmt_mmn <- function(mean_val, median_val, n) {
  ## e.g. 50.1/50/8,984
  paste0(
    formatC(round(mean_val, 1), format = "f", digits = 1),
    "/",
    formatC(round(median_val, 0), format = "d"),
    "/",
    fmt_count(n)
  )
}

fmt_pct <- function(p, digits = 0) {
  paste0(formatC(round(p, digits), format = "f", digits = digits), "%")
}

## ---------------------------------------------------------------------------
## Core aggregation helpers (data.table)
## ---------------------------------------------------------------------------

## Summarise cohort + baseline SGP for an arbitrary grouping.
summarise_sgp <- function(dt, by) {
  dt[, .(
    mean_cohort   = mean(SGP, na.rm = TRUE),
    median_cohort = as.numeric(median(SGP, na.rm = TRUE)),
    n_cohort      = sum(!is.na(SGP)),
    mean_baseline   = mean(SGP_BASELINE, na.rm = TRUE),
    median_baseline = as.numeric(median(SGP_BASELINE, na.rm = TRUE)),
    n_baseline      = sum(!is.na(SGP_BASELINE))
  ), by = by]
}

## Level distribution (Low/Typical/High) for a norm type given the level column.
summarise_levels <- function(dt, level_col, by) {
  x <- dt[!is.na(get(level_col)),
          .(n = .N), by = c(by, level_col)]
  x[, pct := 100 * n / sum(n), by = by]
  setnames(x, level_col, "LEVEL")
  x[]
}
