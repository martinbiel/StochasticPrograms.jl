"""
    SAA

Default `SampledSolver`. Generates a `StochasticSolution` using the sample average approximation (SAA) method, to the desired confidence level.
"""
mutable struct SAA <: AbstractSampledOptimizer
    solution::StochasticSolution

    function SAA()
        return new(EmptySolution())
    end
end

function optimize_sampled!(saa::SAA,
                           stochasticmodel::StochasticModel,
                           sampler::AbstractSampler,
                           confidence::AbstractFloat;
                           M::Integer = 10,
                           T::Integer = 10,
                           Ñ::Integer = 1000,
                           tol::AbstractFloat = 1e-2,
                           Ninit::Int = 16,
                           Nmax::Integer = 5000,
                           optimize_config::Function = (optimizer,N) -> nothing,
                           log = true)
    N = Ninit
    α = 1-confidence
    progress = ProgressThresh(tol, 0.0, "SAA gap")
    log && ProgressMeter.update!(progress, Inf,
                                 showvalues = [
                                     ("Confidence interval", NaN),
                                     ("Relative error", Inf),
                                     ("Sample size", NaN),
                                     ("Current sample size", N)
                                 ])
    while true
        CI = confidence_interval(stochasticmodel, sampler; confidence = 1-α, N = N, M = M, Ñ = max(N, Ñ), T = T, log = log, keep = false, offset = 6, indent = 4)
        Q = (upper(CI) + lower(CI))/2
        gap = length(CI)/abs(Q+1e-10)
        log && ProgressMeter.update!(progress, gap,
                                     showvalues = [
                                         ("Confidence interval", CI),
                                         ("Relative error", gap),
                                         ("Sample size", N),
                                         ("Current sample size", 2*N)
                                     ])
        if gap <= tol
            sp = sample(stochasticmodel, sampler, N; optimizer = optimizer_constructor(stochasticmodel))
            optimize!(sp)
            Q = optimal_value(sp)
            while !(Q ∈ CI)
                sp = sample(stochasticmodel, sampler, N; optimizer = optimizer_constructor(stochasticmodel))
                optimize!(sp)
                Q = optimal_value(sp)
            end
            saa.solution = StochasticSolution(optimal_decision(sp), Q, N, CI)
            return MOI.OPTIMAL
        end
        N = N * 2
        if N > Nmax
            return MOI.ITERATION_LIMIT
        end
        #optimizer_config(optimizer(stochasticmodel), N)
    end
end

function internal_solver(solver::SAA)
    return internal_solver(solver.internal_solver)
end

function optimal_value(saa::SAA)
    if no_solution(saa.solution)
        throw(OptimizeNotCalled())
    end
    return saa.solution.interval
end
