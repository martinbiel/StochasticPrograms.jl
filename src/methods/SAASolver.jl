"""
    SAASolver

Default `SampledSolver`. Generates a `StochasticSolution` through sequential SAA sampling to the desired confidence level.
"""
struct SAASolver{S <: SPSolverType} <: AbstractSampledSolver
    internal_solver::S

    function SAASolver(solver::SPSolverType)
        if isa(solver, JuMP.UnsetSolver)
            error("Cannot solve emerging SAA problems without functional solver.")
        end
        S = typeof(solver)
        return new{S}(solver)
    end
end
"""
    SAASolver(; solver::SPSolverType = JuMP.UnsetSolver())

Return an SAASolver where the emerging SAA problems are solved using `solver`.
"""
function SAASolver(; solver::SPSolverType = JuMP.UnsetSolver())
    return SAASolver(solver)
end

mutable struct SAAModel{M <: StochasticModel, S <: SPSolverType} <: AbstractSampledModel
    stochasticmodel::M
    solver::S
    solution::StochasticSolution
end

function SampledModel(stochasticmodel::StochasticModel, solver::SAASolver)
    return SAAModel(stochasticmodel, solver.internal_solver, EmptySolution())
end

function optimize_sampled!(saamodel::SAAModel, sampler::AbstractSampler, confidence::AbstractFloat; M::Integer = 10, tol::AbstractFloat = 1e-1, Nmax::Integer = 5000)
    sm = saamodel.stochasticmodel
    solver = saamodel.solver
    n = 16
    α = 1-confidence
    while true
        CI = confidence_interval(sm, sampler; solver = solver, confidence = 1-α, N = n, M = M)
        saa = SAA(sm, sampler, n)
        optimize!(saa, solver = solver)
        Q = optimal_value(saa)
        if length(CI)/abs(Q+1e-10) <= tol && Q ∈ CI
            saamodel.solution = StochasticSolution(optimal_decision(saa), Q, CI)
            return :Optimal
        end
        n = n * 2
        if n > Nmax
            return :LimitReached
        end
    end
end

function internal_solver(solver::SAASolver)
    return internal_solver(solver.internal_solver)
end

function stochastic_solution(saamodel::SAAModel)
    return saamodel.solution
end
