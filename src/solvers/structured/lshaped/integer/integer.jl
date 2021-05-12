# Integer API #
# ------------------------------------------------------------
initialize_integer_algorithm!(lshaped::AbstractLShaped) = initialize_integer_algorithm!(lshaped.integer, lshaped.structure.first_stage)
initialize_integer_algorithm!(subproblem::SubProblem) = initialize_integer_algorithm!(subproblem.integer_algorithm, subproblem)
# ------------------------------------------------------------
# Attributes #
# ------------------------------------------------------------
"""
    RawIntegerAlgorithmParameter

An optimizer attribute used for raw parameters of the integer algorithm. Defers to `RawParameter`.
"""
struct RawIntegerParameter <: IntegerParameter
    name::Any
end

include("common.jl")
include("ignore_integers.jl")
include("combinatorial_cuts.jl")
include("convexification.jl")
