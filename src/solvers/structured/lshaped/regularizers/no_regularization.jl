# No regularization
# ------------------------------------------------------------
"""
    NoRegularization

Empty functor object for running an L-shaped algorithm without regularization.

"""
struct NoRegularization <: AbstractRegularization end

function initialize_regularization!(::AbstractLShapedSolver, ::NoRegularization)
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
"""
    DontRegularize

Factory object for [`NoRegularization`](@ref). Passed by default to `regularize ` in the `LShapedSolver` factory function.

"""
struct DontRegularize <: AbstractRegularizer end

function (::DontRegularize)(::AbstractVector)
    return NoRegularization()
end

function str(::DontRegularize)
    return "L-shaped"
end
