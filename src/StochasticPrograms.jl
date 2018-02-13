module StochasticPrograms

using JuMP, MacroTools, MathProgBase
using MacroTools.@q

export
    StochasticProgram,
    AbstractScenarioData,
    stochastic,
    scenario,
    scenarios,
    probability,
    subproblem,
    subproblems,
    num_scenarios,
    @define_subproblem,
    DEP,
    EVP

include("util.jl")
include("stochasticprogram.jl")
include("dep.jl")
include("evp.jl")
include("struct.jl")

end # module
