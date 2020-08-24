# install/link packages in renv lockfile
renv::restore()

# load required packages
if (!require("pacman")) install.packages("pacman")
pacman::p_load(
  tidyverse, tictoc, doFuture,
  fixest, broom, furrr, renv
)

# set up parallelization
registerDoFuture()
plan(multiprocess)

# set RNG seed
set.seed(1234321)

# read in data
df <- read_csv("data/final_panel.csv")
df

# Number of bootstrap resamples
N <- 200

# initialize list of times
times <- list()

# initialize storage df
bootstrap_samples <- tibble()

# define bootstrap function
bootstrap_ses <- function(N) {
  df %>%
    dplyr::sample_frac(replace = TRUE) %>%
    fixest::feols(I(log(abundance)) ~ I(log(gdppc)) + temp_avg + precip_avg + interact(year, state) |
                    location_id + year, data = .) %>%
    broom::tidy() %>%
    dplyr::filter(stringr::str_detect(term, "gdppc")) %>%
    dplyr::select(estimate)
}

# bootstrap sequentially
tic()
serial_feols <- replicate(N, bootstrap_ses(N)) %>%
  unlist() %>%
  as_tibble() %>%
  mutate(type = "serial")
time <- toc()
times[["serial_feols"]] <- time$toc - time$tic

# bootstrap in parallel with parallel for loop
tic()
dopar_feols <- foreach(n = seq(N)) %dopar% {
  bootstrap_ses(n)
} %>%
  unlist() %>%
  as_tibble() %>%
  mutate(type = "dopar")
time <- toc()
times[["dopar_feols"]] <- time$toc - time$tic

# bootstrap in parallel with future map
tic()
furrr_feols <- future_map_dfr(
  seq(N),
  bootstrap_ses,
  .options = future_options(globals = "df")
) %>%
  unlist() %>%
  as_tibble() %>%
  mutate(type = "furrr")
time <- toc()
times[["furrr_feols"]] <- time$toc - time$tic

times

bind_rows(serial_feols, dopar_feols, furrr_feols) %>%
  group_by(type) %>%
  summarise(sd(value))