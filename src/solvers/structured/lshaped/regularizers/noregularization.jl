# No regularization
# ------------------------------------------------------------
struct NoRegularization <: AbstractRegularization end

function init_regularization!(::AbstractLShapedSolver, ::NoRegularization)
    return nothing
end

function log_regularization!(::AbstractLShapedSolver, ::NoRegularization)
    return nothing
end

function log_regularization!(::AbstractLShapedSolver, ::Integer, ::NoRegularization)
    return nothing
end

function take_step!(::AbstractLShapedSolver, ::NoRegularization)
    return nothing
end

function decision(lshaped::AbstractLShapedSolver, ::NoRegularization)
    return lshaped.x
end

function objective(lshaped::AbstractLShapedSolver, ::NoRegularization)
    return lshaped.data.Q
end

function gap(lshaped::AbstractLShapedSolver, ::NoRegularization)
    @unpack Q,θ = lshaped.data
    return abs(θ-Q)/(abs(Q)+1e-10)
end

function add_regularization_params!(::NoRegularization; kwargs...)
    return nothing
end

# API
# ------------------------------------------------------------
struct DontRegularize <: AbstractRegularizer end

function (::DontRegularize)(::AbstractVector)
    return NoRegularization()
end

function str(::DontRegularize)
    return "L-shaped"
end
