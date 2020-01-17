# Common
# ------------------------------------------------------------
function add_regularization_params!(regularizer::AbstractRegularizer; kwargs...)
    push!(regularizer.parameters, kwargs...)
    return nothing
end

function decision(::AbstractLShapedSolver, regularizer::AbstractRegularization)
    return regularizer.ξ
end

function objective(::AbstractLShapedSolver, regularizer::AbstractRegularization)
    return regularizer.data.Q̃
end

function solve_problem!(lshaped::AbstractLShapedSolver, solver::LQSolver, ::AbstractRegularization)
    solver(lshaped.mastervector)
    return nothing
end

function gap(lshaped::AbstractLShapedSolver, regularizer::AbstractRegularization)
    @unpack θ = lshaped.data
    @unpack Q̃ = regularizer.data
    return abs(θ-Q̃)/(abs(Q̃)+1e-10)
end

function process_cut!(lshaped::AbstractLShapedSolver, cut::AbstractHyperPlane, ::AbstractRegularization)
    return nothing
end

function project!(lshaped::AbstractLShapedSolver, ::AbstractRegularization)
    return nothing
end

function add_regularization_params!(regularizer::AbstractRegularization; kwargs...)
    push!(regularizer.params, kwargs...)
    return nothing
end
