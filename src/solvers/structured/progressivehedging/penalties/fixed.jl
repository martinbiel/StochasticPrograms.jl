# FixedPenalization penalty
# ------------------------------------------------------------
"""
    FixedPenalization

Functor object for using fixed penalty in a progressive-hedging algorithm. Create by supplying a [`Fixed`](@ref) object through `penalty` in the `ProgressiveHedgingSolver` factory function and then pass to a `StochasticPrograms.jl` model.

...
# Parameters
- `r::T = 1.00`: Fixed penalty
...
"""
struct FixedPenalization{T <: AbstractFloat} <: AbstractPenalization
    r::T

    function FixedPenalization(r::AbstractFloat)
        T = typeof(r)
        return new{T}(r)
    end
end
function penalty(::AbstractProgressiveHedging, penalty::FixedPenalization)
    return penalty.r
end
function initialize_penalty!(::AbstractProgressiveHedging, ::FixedPenalization)
    nothing
end
function update_penalty!(::AbstractProgressiveHedging, ::FixedPenalization)
    nothing
end

# API
# ------------------------------------------------------------
"""
    Fixed

Factory object for [`FixedPenalization`](@ref). Pass to `penalty` in the `ProgressiveHedgingSolver` factory function. See ?FixedPenalization for parameter descriptions.

"""
struct Fixed{T <: AbstractFloat} <: AbstractPenalizer
    r::T

    function Fixed(; r::AbstractFloat = 1.0)
        T = typeof(r)
        return new{T}(r)
    end
end

function (fixed::Fixed)()
    return FixedPenalization(fixed.r)
end

function str(::Fixed)
    return "fixed penalty"
end
