struct SPResult
    x̄::Vector{Float64}
    VRP::Float64
    EWS::Float64
    EVPI::Float64
    VSS::Float64
    EV::Float64
    EEV::Float64
end

problems = Vector{Tuple{StochasticProgram,SPResult,String}}()
@info "Loading test problems..."
@info "Loading simple..."
include("simple.jl")
@info "Loading instant simple..."
include("instant_simple.jl")
@info "Loading infeasible..."
include("infeasible.jl")
@info "Loading deferred simple..."
include("deferred.jl")
@info "Loading farmer..."
include("farmer.jl")
@info "Loading sampler..."
include("sampler.jl")
@info "Test problems loaded. Starting test sequence."
