# Integer API #
# ------------------------------------------------------------
# initialize_regularization!(lshaped::AbstractLShaped) = initialize_regularization!(lshaped, lshaped.regularization)
# restore_regularized_master!(lshaped::AbstractLShaped) = restore_regularized_master!(lshaped, lshaped.regularization)
# filter_variables!(lshaped::AbstractLShaped, list) = filter_variables!(lshaped.regularization, list)
# filter_constraints!(lshaped::AbstractLShaped, list) = filter_constraints!(lshaped.regularization, list)
# log_regularization!(lshaped::AbstractLShaped) = log_regularization!(lshaped, lshaped.regularization)
# log_regularization!(lshaped::AbstractLShaped, t::Integer) = log_regularization!(lshaped, t, lshaped.regularization)
# take_step!(lshaped::AbstractLShaped) = take_step!(lshaped, lshaped.regularization)
# decision(lshaped::AbstractLShaped) = decision(lshaped, lshaped.regularization)
# objective_value(lshaped::AbstractLShaped) = objective_value(lshaped, lshaped.regularization)
# gap(lshaped::AbstractLShaped) = gap(lshaped, lshaped.regularization)
# process_cut!(lshaped::AbstractLShaped, cut::AbstractHyperPlane) = process_cut!(lshaped, cut, lshaped.regularization)
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
