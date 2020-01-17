function work_on_subproblems!(subworker::SubWorker{T,A,S},
                              work::Work,
                              finalize::Work,
                              progress::ProgressQueue{T},
                              x̄::RunningAverage{A},
                              δ::RunningAverage{T},
                              decisions::Decisions{A},
                              r::IteratedValue{T}) where {T <: Real, A <: AbstractArray, S <: LQSolver}
    subproblems::Vector{SubProblem{T,A,S}} = fetch(subworker)
    if isempty(subproblems)
       # Workers has nothing do to, return.
       return nothing
    end
    quit = false
    while true
        t::Int = try
            if isready(finalize)
                quit = true
                take!(finalize)
            else
                wait(work)
                take!(work)
            end
        catch err
            if err isa InvalidStateException
                # Master closed the work/finalize channel. Worker finished
                return nothing
            end
        end
        t == -1 && continue
        ξ::A = fetch(decisions, t)
        if t > 1
            update_subproblems!(subproblems, ξ, fetch(r,t-1))
        end
        for (i,subproblem) ∈ enumerate(subproblems)
            !quit && take!(δ, i)
            !quit && take!(x̄, i)
            !quit && put!(δ, i, norm(subproblem.x - ξ, 2)^2, subproblem.π)
            reformulate_subproblem!(subproblem, ξ, fetch(r,t))
            Q::T = subproblem()
            !quit && put!(x̄, i, subproblem.π)
            !quit && put!(progress, (t,subproblem.id,Q))
        end
        if quit
            # Worker finished
            return nothing
        end
    end
end
