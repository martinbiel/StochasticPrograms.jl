function work_on_subproblems!(subworker::SubWorker{T,A,S},
                              work::Work,
                              progress::ProgressQueue{T},
                              x̄::RunningAverage{A},
                              δ::RunningAverage{T},
                              decisions::Decisions{A},
                              r::IteratedValue{T}) where {T <: Real, A <: AbstractArray, S <: LQSolver}
    subproblems::Vector{SubProblem{T,A,S}} = fetch(subworker)
    if isempty(subproblems)
       # Workers has nothing do to, return.
       return
    end
    while true
        t::Int = try
            wait(work)
            take!(work)
        catch err
            if err isa InvalidStateException
                # Master closed the work channel. Worker finished
                return
            end
        end
        if t == -1
            # Worker finished
            return
        end
        ξ::A = fetch(decisions, t)
        if t > 1
            update_subproblems!(subproblems, ξ, fetch(r,t-1))
        end
        @sync for (i,subproblem) ∈ enumerate(subproblems)
            @async begin
                take!(δ, i)
                take!(x̄, i)
                put!(δ, i, norm(subproblem.x - ξ, 2)^2, subproblem.π)
                reformulate_subproblem!(subproblem, ξ, fetch(r,t))
                Q::T = subproblem()
                put!(x̄, i, subproblem.π)
                put!(progress, (t,subproblem.id,Q))
            end
        end
    end
end
