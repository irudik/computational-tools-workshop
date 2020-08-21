# Load julia packages for data work and estimation
using Pkg
Pkg.activate(".")
using Distributed

# add 1 worker
addprocs(1)

@everywhere begin
  using Pkg
  Pkg.activate(".")
  Pkg.instantiate()
  using Queryverse, FixedEffectModels, SharedArrays
end

# set RNG seed
Random.seed!(1234321)

# load dataframe
df = DataFrame(load("data/final_panel.csv"))

@everywhere function bootstrap_ses(df)
    bootstrap_df = df[sample(axes(df, 1), nrow(df); replace = true), :]
    reg_output = reg(bootstrap_df,
        @formula(log(abundance) ~ log(gdppc) + temp_avg + precip_avg + fe(state)&year + fe(location_id) + fe(year)))

    return reg_output.coef[1]
end


# serial
estimates_serial = Vector{Float64}(undef, N)
@time for i in 1:N
  estimates_serial[i] = bootstrap_ses(df)
end


# parallel map
@time estimates_pmap = pmap(bootstrap_ses, [df for i in 1:N])

# distributed
estimates_distrib = SharedArray{Float64}(N)
@time @sync @distributed for i in 1:N
  estimates_distrib[i] = bootstrap_ses(df)
end
