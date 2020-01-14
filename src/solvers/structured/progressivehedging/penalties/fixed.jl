# FixedPenalization penalty
# ------------------------------------------------------------
struct FixedPenalization{T <: AbstractFloat} <: AbstractPenalization
    r::T

    function FixedPenalization(r::AbstractFloat)
        T = typeof(r)
        return new{T}(r)
    end
end
function penalty(::AbstractProgressiveHedgingSolver, penalty::FixedPenalization)
    return penalty.r
end
function init_penalty!(::AbstractProgressiveHedgingSolver, ::FixedPenalization)
    nothing
end
function update_penalty!(::AbstractProgressiveHedgingSolver, ::FixedPenalization)
    nothing
end

# API
# ------------------------------------------------------------
"""
    Fixed

...
# Parameters
- `r::AbstractFloat = 1.0`: Penalty parameter
...
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
