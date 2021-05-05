# No regularization
# ------------------------------------------------------------
"""
    NoRegularization

Empty functor object for running an L-shaped algorithm without regularization.

"""
struct NoRegularization <: AbstractRegularization end

function initialize_regularization!(::AbstractLShaped, ::NoRegularization)
    return nothing
end

function restore_regularized_master!(::AbstractLShaped, ::NoRegularization)
    return nothing
end

function filter_variables!(::NoRegularization, ::Any)
    return nothing
end

function filter_constraints!(::NoRegularization, ::Any)
    return nothing
end

function log_regularization!(::AbstractLShaped, ::NoRegularization)
    return nothing
end

function log_regularization!(::AbstractLShaped, ::Integer, ::NoRegularization)
    return nothing
end

function take_step!(::AbstractLShaped, ::NoRegularization)
    return nothing
end

function decision(lshaped::AbstractLShaped, ::NoRegularization)
    return lshaped.x
end

function objective_value(lshaped::AbstractLShaped, ::NoRegularization)
    return lshaped.data.Q
end

function gap(lshaped::AbstractLShaped, ::NoRegularization)
    @unpack Q,θ = lshaped.data
    return abs(θ-Q)/(abs(Q)+1e-10)
end

# API
# ------------------------------------------------------------
"""
    DontRegularize

Factory object for [`NoRegularization`](@ref). Passed by default to `regularize` in `LShaped.Optimizer`.

"""
struct DontRegularize <: AbstractRegularizer end

function (::DontRegularize)(::DecisionMap, ::AbstractVector)
    return NoRegularization()
end

function str(::DontRegularize)
    return "L-shaped"
end
