abstract type PenaltyTerm end

mutable struct Quadratic <: PenaltyTerm
    c::AbstractVector

    Quadratic() = new()
end

function initialize_penalty!(penalty::Quadratic, solver::LQSolver, c::AbstractVector)
    # Get model handle
    model = solver.lqmodel
    # Check if quadratic objectives can be set
    if !applicable(MPB.setquadobj!, model, Int[], Int[], Float64[])
        error("Using a quadratic penalty term requires a solver that can handle quadratic objectives")
    end
    # Cache initial linear objective
    penalty.c = c
    return nothing
end

function update_penalty!(penalty::Quadratic, solver::LQSolver, α::AbstractFloat, ξ::AbstractVector)
    # Get model handle
    model = solver.lqmodel
    # Get current linear cost
    c = MPB.getobj(model)
    # Linear part
    c[1:length(ξ)] .= penalty.c - α*ξ
    MPB.setobj!(model, c)
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

function solve!(::Quadratic, solver::LQSolver, X::AbstractVector, ::AbstractVector, ::AbstractVector)
    solver(X)
    return nothing
end

mutable struct Linearized <: PenaltyTerm
    index::Int
    nbreakpoints::Int

    Linearized(; nbreakpoints = 3) = new(-1, nbreakpoints)
end

function initialize_penalty!(penalty::Linearized, solver::LQSolver, ::AbstractVector)
    # Set constraint index to -1 to indicate that ∞-norm terms have not yet been added
    penalty.index = -1
    # Get model handle
    model = solver.lqmodel
    # Add auxilliary cost variable
    MPB.addvar!(model, 0.0, Inf, 1.0)
    return nothing
end

function update_penalty!(penalty::Linearized, solver::LQSolver, α::AbstractFloat, ξ::AbstractVector)
    # Get model handle
    model = solver.lqmodel
    # Get number of master variables
    ncols = length(ξ)
    # Get current linear cost
    c = MPB.getobj(model)
    # The ∞-norm aux variable is the last variable
    tidx = length(c)
    # Get current position of linearization constraints
    j = penalty.index
    if j != -1
        # Delete previous constraints (if they exist)
        MPB.delconstrs!(model, collect(j:j+penalty.nbreakpoints-1))
    end
    x = MPB.getsolution(model)[1:ncols]
    Δ = x-ξ
    breakpoints = LinRange(ξ-Δ, ξ+Δ, penalty.nbreakpoints)
    # Add new (or first) set of ∞-norm constraints
    for x in breakpoints
        f = 0.5*norm(x-ξ)^2
        g = α*(x-ξ)
        MPB.addconstr!(model, vcat(1:ncols,tidx), vcat(-g,1.), f-g⋅ξ, Inf)
    end
    # Update the position of the constraints
    penalty.index = MPB.numconstr(model)-(penalty.nbreakpoints-1)
    return nothing
end

function solve!(penalty::Linearized, solver::LQSolver, X::AbstractVector, x::AbstractVector, ξ::AbstractVector)
    push!(X, norm(x-ξ, 2)^2)
    solver(X)
    pop!(X)
    return nothing
end

mutable struct InfNorm <: PenaltyTerm
    index::Int

    InfNorm() = new(-1)
end

function initialize_penalty!(penalty::InfNorm, solver::LQSolver, ::AbstractVector)
    # Set constraint index to -1 to indicate that ∞-norm terms have not yet been added
    penalty.index = -1
    # Get model handle
    model = solver.lqmodel
    # Add ∞-norm auxilliary variable
    MPB.addvar!(model, -Inf, Inf, 1.0)
    return nothing
end

function update_penalty!(penalty::InfNorm, solver::LQSolver, α::AbstractFloat, ξ::AbstractVector)
    # Get model handle
    model = solver.lqmodel
    # Get number of master variables
    ncols = length(ξ)
    # Get current linear cost
    c = MPB.getobj(model)
    # The ∞-norm aux variable is the last variable
    tidx = length(c)
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

function solve!(penalty::InfNorm, solver::LQSolver, X::AbstractVector, x::AbstractVector, ξ::AbstractVector)
    push!(X, norm(x-ξ, Inf))
    solver(X)
    pop!(X)
    return nothing
end

mutable struct ManhattanNorm <: PenaltyTerm
    index::Int

    ManhattanNorm() = new(-1)
end

function initialize_penalty!(penalty::ManhattanNorm, solver::LQSolver, c::AbstractVector)
    # Set constraint index to -1 to indicate that 1-norm terms have not yet been added
    penalty.index = -1
    # Get model handle
    model = solver.lqmodel
    # Add 1-norm auxilliary variables
    ncols = length(c)
    for i in 1:ncols
        MPB.addvar!(model, -Inf, Inf, 1.0)
    end
    return nothing
end

function update_penalty!(penalty::ManhattanNorm, solver::LQSolver, α::AbstractFloat, ξ::AbstractVector)
    # Get model handle
    model = solver.lqmodel
    # Get number of master variables
    ncols = length(ξ)
    # Get current linear cost
    c = MPB.getobj(model)
    # The 1-norm aux variables are the last ncols variables
    tidx = length(c)-length(ξ)+1
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

function solve!(penalty::ManhattanNorm, solver::LQSolver, X::AbstractVector, x::AbstractVector, ξ::AbstractVector)
    ts = map(abs, x .- ξ)
    append!(X, ts)
    solver(X)
    [pop!(X) for _ in ts]
    return nothing
end
