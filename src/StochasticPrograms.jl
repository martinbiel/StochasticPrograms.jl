module StochasticPrograms

using JuMP, MacroTools
using MacroTools.@q

export
    StochasticProgram,
    getsubproblem,
    getprobability,
    num_scenarios,
    @define_subproblem

include("stochasticprogram.jl")
include("dep.jl")
include("evp.jl")
include("struct.jl")

end # module
