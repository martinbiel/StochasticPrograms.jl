"""
    ConfidenceInterval

An estimated interval around an unknown quantity at a given confidence level
"""
struct ConfidenceInterval{T <: AbstractFloat}
    lower::T
    upper::T
    confidence::T

    function ConfidenceInterval(lower::AbstractFloat, upper::AbstractFloat, confidence::AbstractFloat)
        T = promote_type(typeof(lower), typeof(upper), typeof(confidence), Float32)
        lower <= upper || error("Inconsistent confidence interval: $lower ≰ $upper")
        return new{T}(lower, upper, confidence)
    end
end
lower(interval::ConfidenceInterval) = interval.lower
upper(interval::ConfidenceInterval) = interval.upper
confidence(interval::ConfidenceInterval) = interval.confidence
length(interval::ConfidenceInterval) = upper(interval) - lower(interval)
function in(x::T, interval::ConfidenceInterval) where T <: Real
    isinf(x) && return false
    return interval.lower <= x <= interval.upper
end
function issubset(a::ConfidenceInterval, b::ConfidenceInterval)
    return a.lower >= b.lower && a.upper <= b.upper
end
function show(io::IO, interval::ConfidenceInterval)
    intervalstr = @sprintf "Confidence interval (p = %.0f%%): [%.2f − %.2f]" 100*interval.confidence interval.lower interval.upper
    print(io, intervalstr)
    return io
end
