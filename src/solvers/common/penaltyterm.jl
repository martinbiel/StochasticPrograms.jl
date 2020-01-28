abstract type PenaltyTerm end

Base.copy(::PT) where PT <: PenaltyTerm = PT()

"""
    Quadratic

Functor object for using a quadratic 2-norm penalty term. Requires an `AbstractMathProgSolver` capable of solving QP problems. Passed by default through `penalty` where applicable.

"""
mutable struct Quadratic <: PenaltyTerm end

function initialize_penaltyterm!(penalty::Quadratic, solver::LQSolver, ::AbstractVector)
    # Get model handle
    model = solver.lqmodel
    # Check if quadratic objectives can be set
    if !applicable(MPB.setquadobj!, model, Int[], Int[], Float64[])
        error("Using a quadratic penalty term requires a solver that can handle quadratic objectives")
    end
    return nothing
end

function update_penaltyterm!(penalty::Quadratic, solver::LQSolver, c::AbstractVector, α::AbstractFloat, ξ::AbstractVector)
    # Get model handle
    model = solver.lqmodel
    # Cache current linear cost
    c_ = copy(c)
    # Linear part
    c_[1:length(ξ)] -= α*ξ
    MPB.setobj!(model, c_)
    # Quadratic part
    qidx = collect(1:length(c))
    qval = fill(α, length(c))
    qval[length(ξ)+1:end] .= zero(α)
    if applicable(MPB.setquadobj!, model, qidx, qidx, qval)
        MPB.setquadobj!(model, qidx, qidx, qval)
    else
        error("Using a quadratic penalty term requires a solver that can handle quadratic objectives")
    end
    return nothing
end

function solve_penalized!(::Quadratic, solver::LQSolver, X::AbstractVector, ::AbstractVector, ::AbstractVector)
    solver(X)
    return nothing
end

"""
    Linearized

Functor object for using an approximately quadratic penalty term, through linearization. Pass through `penalty` where applicable.

...
# Parameters
- `nbreakpoints::Int`: Number of cutting planes used to approximate quadratic term
...
"""
mutable struct Linearized <: PenaltyTerm
    index::Int
    nbreakpoints::Int

    function Linearized(index::Integer, nbreakpoints::Integer)
        n = nbreakpoints >= 3 ? nbreakpoints : 3
        new(index, n)
    end
end
Linearized(; nbreakpoints = 3) = Linearized(-1, nbreakpoints)
Base.copy(linearized::Linearized) = Linearized(-1, linearized.nbreakpoints)

function initialize_penaltyterm!(penalty::Linearized, solver::LQSolver, ξ::AbstractVector)
    # Set constraint index to -1 to indicate that ∞-norm terms have not yet been added
    penalty.index = -1
    # Get model handle
    model = solver.lqmodel
    # Add auxilliary cost variables
    ncols = length(ξ)
    for i in 1:ncols
        MPB.addvar!(model, 0.0, Inf, 1.0)
    end
    return nothing
end

function update_penaltyterm!(penalty::Linearized, solver::LQSolver, c::AbstractVector, α::AbstractFloat, ξ::AbstractVector)
    # Get model handle
    model = solver.lqmodel
    # Cache current linear cost
    c_ = copy(c)
    # Get number of master variables
    ncols = length(ξ)
    # The aux cost variable is the last variable
    tidx = length(c)+1
    # Linear part
    c_[1:length(ξ)] -= α*ξ
    MPB.setobj!(solver.lqmodel, vcat(c_, fill(1.0, length(ξ))))
    # Get current position of linearization constraints
    j = penalty.index
    if j != -1
        # Delete previous constraints (if they exist)
        MPB.delconstrs!(model, collect(j:j+ncols*penalty.nbreakpoints-1))
    end
    x = MPB.getsolution(model)[1:ncols]
    # Add new (or first) set of linearized cost constraints
    for i in 1:ncols
        breakpoints = LinRange(0.0, 2*ξ[i], penalty.nbreakpoints)
        for x in breakpoints
            f = 0.5*α*x^2
            g = α*x
            MPB.addconstr!(model, [i,tidx+(i-1)], [-g,1.], f-g*x, Inf)
        end
    end
    # Update the position of the constraints
    penalty.index = MPB.numconstr(model)-(ncols*penalty.nbreakpoints-1)
    return nothing
end

function solve_penalized!(penalty::Linearized, solver::LQSolver, X::AbstractVector, x::AbstractVector, ξ::AbstractVector)
    push!(X, norm(x-ξ, 2)^2)
    solver(X)
    pop!(X)
    return nothing
end

"""
    InfNorm

Functor object for using a linear ∞-norm penalty term. Pass through `penalty` where applicable.

"""
mutable struct InfNorm <: PenaltyTerm
    index::Int

    InfNorm() = new(-1)
end

function initialize_penaltyterm!(penalty::InfNorm, solver::LQSolver, ::AbstractVector)
    # Set constraint index to -1 to indicate that ∞-norm terms have not yet been added
    penalty.index = -1
    # Get model handle
    model = solver.lqmodel
    # Add ∞-norm auxilliary variable
    MPB.addvar!(model, -Inf, Inf, 1.0)
    return nothing
end

function update_penaltyterm!(penalty::InfNorm, solver::LQSolver, c::AbstractVector, α::AbstractFloat, ξ::AbstractVector)
    # Get model handle
    model = solver.lqmodel
    # Get number of master variables
    ncols = length(ξ)
    # The ∞-norm aux variable is the last variable
    tidx = length(c)+1
    # Linear part
    MPB.setobj!(solver.lqmodel, vcat(c,1.0))
    # Get current position of ∞-norm constraints
    j = penalty.index
    if j != -1
        # Delete previous constraints (if they exist)
        MPB.delconstrs!(model, collect(j:j+2*ncols-1))
    end
    # Add new (or first) set of ∞-norm constraints
    for i in 1:ncols
        MPB.addconstr!(model, [i,tidx], [-α,1], -α*ξ[i], Inf)
        MPB.addconstr!(model, [i,tidx], [-α,-1], -Inf, -α*ξ[i])
    end
    # Update the position of the constraints
    penalty.index = MPB.numconstr(model)-(2*ncols-1)
    return nothing
end

function solve_penalized!(penalty::InfNorm, solver::LQSolver, X::AbstractVector, x::AbstractVector, ξ::AbstractVector)
    push!(X, norm(x-ξ, Inf))
    solver(X)
    pop!(X)
    return nothing
end

"""
    ManhattanNorm

Functor object for using a linear 1-norm penalty term. Pass through `penalty` where applicable.

"""
mutable struct ManhattanNorm <: PenaltyTerm
    index::Int

    ManhattanNorm() = new(-1)
end

function initialize_penaltyterm!(penalty::ManhattanNorm, solver::LQSolver, ξ::AbstractVector)
    # Set constraint index to -1 to indicate that 1-norm terms have not yet been added
    penalty.index = -1
    # Get model handle
    model = solver.lqmodel
    # Add 1-norm auxilliary variables
    ncols = length(ξ)
    for i in 1:ncols
        MPB.addvar!(model, -Inf, Inf, 1.0)
    end
    return nothing
end

function update_penaltyterm!(penalty::ManhattanNorm, solver::LQSolver, c::AbstractVector, α::AbstractFloat, ξ::AbstractVector)
    # Get model handle
    model = solver.lqmodel
    # Get number of master variables
    ncols = length(ξ)
    # The 1-norm aux variables are the last variables
    tidx = length(c)+1
    # Linear part
    MPB.setobj!(solver.lqmodel, vcat(c, fill(1.0, length(ξ))))
    # Get current position of ∞-norm constraints
    j = penalty.index
    if j != -1
        # Delete previous constraints (if they exist)
        MPB.delconstrs!(model, collect(j:j+2*ncols-1))
    end
    # Add new (or first) set of 1-norm constraints
    for i in 1:ncols
        MPB.addconstr!(model, [i,tidx+(i-1)], [-α,1], -α*ξ[i], Inf)
        MPB.addconstr!(model, [i,tidx+(i-1)], [-α,-1], -Inf, -α*ξ[i])
    end
    # Update the position of the constraints
    penalty.index = MPB.numconstr(model)-(2*ncols-1)
    return nothing
end

function solve_penalized!(penalty::ManhattanNorm, solver::LQSolver, X::AbstractVector, x::AbstractVector, ξ::AbstractVector)
    ts = map(abs, x .- ξ)
    append!(X, ts)
    solver(X)
    [pop!(X) for _ in ts]
    return nothing
end
