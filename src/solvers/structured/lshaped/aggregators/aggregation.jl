abstract type AbstractAggregation end
abstract type AbstractAggregator end
# Aggregation API #
# ------------------------------------------------------------
nthetas(lshaped::AbstractLShapedSolver) = nthetas(lshaped, lshaped.aggregation)
# ------------------------------------------------------------
include("cut_collection.jl")
include("distance_measures.jl")
include("selection_rules.jl")
include("cluster_rules.jl")
include("lock_rules.jl")
include("no_aggregation.jl")
include("partial_aggregation.jl")
include("dynamic_aggregation.jl")
include("cluster_aggregation.jl")
include("hybrid_aggregation.jl")
