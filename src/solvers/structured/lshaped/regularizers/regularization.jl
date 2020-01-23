abstract type AbstractRegularization end
abstract type AbstractRegularizer end
# Regularization API #
# ------------------------------------------------------------
initialize_regularization!(lshaped::AbstractLShapedSolver) = initialize_regularization!(lshaped, lshaped.regularization)
log_regularization!(lshaped::AbstractLShapedSolver) = log_regularization!(lshaped, lshaped.regularization)
log_regularization!(lshaped::AbstractLShapedSolver, t::Integer) = log_regularization!(lshaped, t, lshaped.regularization)
take_step!(lshaped::AbstractLShapedSolver) = take_step!(lshaped, lshaped.regularization)
decision(lshaped::AbstractLShapedSolver) = decision(lshaped, lshaped.regularization)
objective(lshaped::AbstractLShapedSolver) = objective(lshaped, lshaped.regularization)
solve_problem!(lshaped::AbstractLShapedSolver, solver::LQSolver) = solve_problem!(lshaped, solver, lshaped.regularization)
gap(lshaped::AbstractLShapedSolver) = gap(lshaped, lshaped.regularization)
process_cut!(lshaped::AbstractLShapedSolver, cut::AbstractHyperPlane) = process_cut!(lshaped, cut, lshaped.regularization)
project!(lshaped::AbstractLShapedSolver) = project!(lshaped, lshaped.regularization)
# ------------------------------------------------------------
include("common.jl")
include("no_regularization.jl")
include("rd.jl")
include("tr.jl")
include("lv.jl")
include("util.jl")
