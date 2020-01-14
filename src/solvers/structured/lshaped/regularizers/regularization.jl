abstract type AbstractRegularization end
abstract type AbstractRegularizer end
# Regularization API #
# ------------------------------------------------------------
init_regularization!(lshaped::AbstractLShapedSolver) = init_regularization!(lshaped, lshaped.regularizer)
log_regularization!(lshaped::AbstractLShapedSolver) = log_regularization!(lshaped, lshaped.regularizer)
log_regularization!(lshaped::AbstractLShapedSolver, t::Integer) = log_regularization!(lshaped, t, lshaped.regularizer)
take_step!(lshaped::AbstractLShapedSolver) = take_step!(lshaped, lshaped.regularizer)
decision(lshaped::AbstractLShapedSolver) = decision(lshaped, lshaped.regularizer)
objective(lshaped::AbstractLShapedSolver) = objective(lshaped, lshaped.regularizer)
solve_problem!(lshaped::AbstractLShapedSolver, solver::LQSolver) = solve_problem!(lshaped, solver, lshaped.regularizer)
gap(lshaped::AbstractLShapedSolver) = gap(lshaped, lshaped.regularizer)
process_cut!(lshaped::AbstractLShapedSolver, cut::AbstractHyperPlane) = process_cut!(lshaped, cut, lshaped.regularizer)
project!(lshaped::AbstractLShapedSolver) = project!(lshaped, lshaped.regularizer)
# ------------------------------------------------------------
include("common.jl")
include("noregularization.jl")
include("rd.jl")
include("tr.jl")
include("lv.jl")
include("util.jl")
