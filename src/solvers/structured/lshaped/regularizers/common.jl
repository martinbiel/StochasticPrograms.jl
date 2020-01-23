# Common
# ------------------------------------------------------------
function add_regularization_params!(regularization::AbstractRegularizer; kwargs...)
    push!(regularization.parameters, kwargs...)
    return nothing
end

function decision(::AbstractLShapedSolver, regularization::AbstractRegularization)
    return regularization.ξ
end

function objective(::AbstractLShapedSolver, regularization::AbstractRegularization)
    return regularization.data.Q̃
end

function solve_problem!(lshaped::AbstractLShapedSolver, solver::LQSolver, ::AbstractRegularization)
    solver(lshaped.mastervector)
    return nothing
end

function gap(lshaped::AbstractLShapedSolver, regularization::AbstractRegularization)
    @unpack θ = lshaped.data
    @unpack Q̃ = regularization.data
    return abs(θ-Q̃)/(abs(Q̃)+1e-10)
end

function process_cut!(lshaped::AbstractLShapedSolver, cut::AbstractHyperPlane, ::AbstractRegularization)
    return nothing
end

function project!(lshaped::AbstractLShapedSolver, ::AbstractRegularization)
    return nothing
end

function add_regularization_params!(regularization::AbstractRegularization; kwargs...)
    push!(regularization.params, kwargs...)
    return nothing
end
