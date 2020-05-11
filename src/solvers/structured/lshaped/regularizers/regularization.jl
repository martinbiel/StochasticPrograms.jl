abstract type AbstractRegularization end
abstract type AbstractRegularizer end
# Regularization API #
# ------------------------------------------------------------
initialize_regularization!(lshaped::AbstractLShaped) = initialize_regularization!(lshaped, lshaped.regularization)
restore_regularized_master!(lshaped::AbstractLShaped) = restore_regularized_master!(lshaped, lshaped.regularization)
log_regularization!(lshaped::AbstractLShaped) = log_regularization!(lshaped, lshaped.regularization)
log_regularization!(lshaped::AbstractLShaped, t::Integer) = log_regularization!(lshaped, t, lshaped.regularization)
take_step!(lshaped::AbstractLShaped) = take_step!(lshaped, lshaped.regularization)
decision(lshaped::AbstractLShaped) = decision(lshaped, lshaped.regularization)
objective_value(lshaped::AbstractLShaped) = objective_value(lshaped, lshaped.regularization)
gap(lshaped::AbstractLShaped) = gap(lshaped, lshaped.regularization)
process_cut!(lshaped::AbstractLShaped, cut::AbstractHyperPlane) = process_cut!(lshaped, cut, lshaped.regularization)
# ------------------------------------------------------------
include("common.jl")
include("no_regularization.jl")
include("rd.jl")
include("tr.jl")
include("lv.jl")
