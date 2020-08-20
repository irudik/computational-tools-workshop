# Load packages
if (!require("pacman")) install.packages("pacman")
pacman::p_load(
  tidyverse, janitor, tictoc, doFuture, lfe,
  parallel, fixest, broom, furrr, renv
)
registerDoFuture()
plan(multiprocess)
set.seed(1234321)

# read in dataset
df <- read_csv("data/final_panel.csv")

# initialize list of times
times <- list()

# Number of bootstraps
N <- 100

##################
##################
### serial felm
##################
##################

bootstrap_ses <- function(df) {
  
  df %>% 
    sample_frac(replace = TRUE) %>% 
    felm(I(log(abundance)) ~ I(log(gdppc)) + temp_avg + precip_avg + as.factor(state)*I(year) |
            location_id + year, data = .) %>% 
    tidy() %>% 
    filter(str_detect(term, "gdppc")) %>% 
    select(estimate)
  
}

tic()
serial_felm <- replicate(N, bootstrap_ses(df))
time <- toc()
times[["serial_felm"]] <- time$toc - time$tic

##################
##################
### serial feols
##################
##################

bootstrap_ses <- function(df) {
  
  df %>% 
    sample_frac(replace = TRUE) %>% 
    feols(I(log(abundance)) ~ I(log(gdppc)) + temp_avg + precip_avg + interact(year, state) |
            location_id + year, data = .) %>% 
    tidy() %>% 
    filter(str_detect(term, "gdppc")) %>% 
    select(estimate)
  
}

tic()
serial_feols <- replicate(N, bootstrap_ses(df))
time <- toc()
times[["serial_feols"]] <- time$toc - time$tic

##################
##################
### dopar
##################
##################

bootstrap_ses <- function(df) {
  
  df %>% 
    dplyr::sample_frac(replace = TRUE) %>% 
    fixest::feols(I(log(abundance)) ~ I(log(gdppc)) + temp_avg + precip_avg + interact(year, state) |
            location_id + year, data = .) %>% 
    broom::tidy() %>% 
    dplyr::filter(str_detect(term, "gdppc")) %>% 
    dplyr::select(estimate)
  
}

tic()
dopar_feols <- foreach(n = seq(N)) %dopar% {
  bootstrap_ses(df)
}
time <- toc()
times[["dopar_feols"]] <- time$toc - time$tic

bootstrap_ses <- function(df) {
  
  df %>% 
    dplyr::sample_frac(replace = TRUE) %>% 
    lfe::felm(I(log(abundance)) ~ I(log(gdppc)) + temp_avg + precip_avg + as.factor(state)*I(year) |
                    location_id + year, data = .) %>% 
    broom::tidy() %>% 
    dplyr::filter(str_detect(term, "gdppc")) %>% 
    dplyr::select(estimate)
  
}

tic()
dopar_feols <- foreach(n = seq(N)) %dopar% {
  bootstrap_ses(df)
}
time <- toc()
times[["dopar_felm"]] <- time$toc - time$tic

##################
##################
### furrr
##################
##################

### feols

bootstrap_ses <- function(N) {
  
  df %>% 
    dplyr::sample_frac(replace = TRUE) %>% 
    fixest::feols(I(log(abundance)) ~ I(log(gdppc)) + temp_avg + precip_avg + interact(year, state) |
                    location_id + year, data = .) %>% 
    broom::tidy() %>% 
    dplyr::filter(str_detect(term, "gdppc")) %>% 
    dplyr::select(estimate)
  
}

tic()
furrr_feols <- future_map_dfr(seq(N), bootstrap_ses, .options = future_options(globals = "df"))
time <- toc()
times[["furrr_feols"]] <- time$toc - time$tic

### lfe