function load_subproblems!(subworkers::Vector{SubWorker{T}},
                           scenarioproblems::DistributedScenarioProblems,
                           decisions::Vector{DecisionChannel}) where T <: AbstractFloat

end

function restore_subproblems!(subworkers::Vector{<:SubWorker})
     @sync begin
        for w in workers()
            @async remotecall_fetch(w, subworkers[w-1]) do sw
                for subproblem in fetch(sw)
                    restore_subproblem!(subproblem)
                end
            end
        end
    end
    return nothing
end
