#######################
### PACKAGE LOADING
#######################

# load and install packages on main core
# run(`pip install xlrd`) # install python xlrd package if not on biohpc
using Pkg
Pkg.activate(".")
Pkg.instantiate()
using Distributed, Random, Statistics

# add other workers
addprocs(convert(Int64, length(Sys.cpu_info())/2))

# load and install packages on all cores
@everywhere using Pkg
@everywhere Pkg.activate(".")
@everywhere Pkg.instantiate()
@everywhere using DataFrames, CSV, FixedEffectModels, SharedArrays, Statistics, Random, StatsBase

#######################
### INITIALIZE
#######################

# set RNG seed
Random.seed!(1234321)

# load data
df = CSV.read("data/final_panel.csv", DataFrame)

# set number of bootstraps
N = 200

# preallocate storage arrays
estimates_serial = Vector{Float64}(undef, N);
estimates_distrib = SharedArray{Float64}(N);

# define bootstrap function
@everywhere function bootstrap_ses(df)
    bootstrap_df = df[sample(axes(df, 1), nrow(df); replace = true), :]
    reg_output = reg(bootstrap_df,
        @formula(log(abundance) ~ log(gdppc) + temp_avg + precip_avg + fe(state)&year + fe(location_id) + fe(year)))

    return reg_output.coef[1]
end

#######################
### PRECOMPILE
#######################

# serial
@time for i in 1:N
  estimates_serial[i] = bootstrap_ses(df)
end

# parallel map
@time estimates_pmap = pmap(bootstrap_ses, [df for i in 1:N]);

# distributed
@time @sync @distributed for i in 1:N
  estimates_distrib[i] = bootstrap_ses(df)
end

#######################
### ACTUAL RUN
#######################

@time for i in 1:N
  estimates_serial[i] = bootstrap_ses(df)
end

@time estimates_pmap = pmap(bootstrap_ses, [df for i in 1:N]);

@time @sync @distributed for i in 1:N
  estimates_distrib[i] = bootstrap_ses(df)
end

#######################
### RESULTS
#######################

results = DataFrame(serial = estimates_serial, pmap = estimates_pmap, distrib = estimates_distrib);
std_devs = describe(results, :std)
