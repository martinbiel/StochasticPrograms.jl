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
"""
    StochasticSolution

Approximate solution to a stochastic model to a given level of confidence.
"""
struct StochasticSolution{T <: AbstractFloat}
    x::DecisionVariables{T}
    Q::T
    N::Int
    interval::ConfidenceInterval{T}

    function StochasticSolution(x::DecisionVariables{T}, Q::AbstractFloat, N::Int, interval::ConfidenceInterval{T}) where T <: AbstractFloat
        return new{T}(x, Q, N, interval)
    end
end

function EmptySolution()
    return StochasticSolution(DecisionVariables(Float64), 0.0, 0, ConfidenceInterval(-Inf, Inf, 1.0))
end

function no_solution(solution::StochasticSolution)
    return ndecisions(solution.x) == 0 && length(solution.interval) == Inf
end

"""
    decision(solution::StochasticSolution)

Return the optimal first stage decision of the approximate `solution` to some stochastic model.
"""
decision(solution::StochasticSolution) = solution.x
"""
    optimal_value(solution::StochasticSolution)

Return the optimal value of the approximate `solution` to some stochastic model
"""
optimal_value(solution::StochasticSolution) = solution.Q
"""
    confidence_interval(solution::StochasticSolution)

Return a confidence interval around the optimal value of the approximate `solution` to some stochastic model
"""
confidence_interval(solution::StochasticSolution) = solution.interval
function show(io::IO, solution::StochasticSolution)
    println(io, "Stochastic solution")
    println(io, "Optimal value: $(solution.Q)")
    print(io, solution.interval)
    return io
end
