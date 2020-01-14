@with_kw mutable struct LShapedData{T <: AbstractFloat}
    Q::T = 1e10
    θ::T = -1e10
    ncuts::Int = 0
    iterations::Int = 0
    consolidations::Int = 0
end

@with_kw mutable struct LShapedParameters{T <: AbstractFloat}
    τ::T = 1e-6
    cut_scaling::T = 1.0
    debug::Bool = false
    log::Bool = true
    keep::Bool = true
    offset::Int = 0
    indent::Int = 0
end

"""
    LShaped

Functor object for the L-shaped algorithm. Create by supplying `:ls` to the `LShapedSolver` factory function and then pass to a `StochasticPrograms.jl` model.

...
# Algorithm parameters
- `τ::Real = 1e-6`: Relative tolerance for convergence checks.
- `debug::Bool = false`: Specifies if extra information should be saved for debugging purposes. Defaults to false for memory efficiency.
- `log::Bool = true`: Specifices if L-shaped procedure should be logged on standard output or not.
...
"""
struct LShaped{T <: AbstractFloat,
               A <: AbstractVector,
               SP <: StochasticProgram,
               M <: LQSolver,
               S <: LQSolver,
               F <: AbstractFeasibility,
               R <: AbstractRegularization,
               Agg <: AbstractAggregation,
               C <: AbstractConsolidation} <: AbstractLShapedSolver
    stochasticprogram::SP
    data::LShapedData{T}
    parameters::LShapedParameters{T}

    # Master
    mastersolver::M
    mastervector::A
    c::A
    x::A
    Q_history::A

    # Subproblems
    nscenarios::Int
    subproblems::Vector{SubProblem{F,T,A,S}}
    subobjectives::A

    # Feasibility
    feasibility::F

    # Regularization
    regularizer::R

    # Cuts
    θs::A
    cuts::Vector{AnySparseOptimalityCut{T}}
    aggregation::Agg
    consolidation::C
    θ_history::A

    progress::ProgressThresh{T}

    function LShaped(stochasticprogram::StochasticProgram,
                     x₀::AbstractVector,
                     mastersolver::MPB.AbstractMathProgSolver,
                     subsolver::MPB.AbstractMathProgSolver,
                     complete_recourse::Bool,
                     regularizer::AbstractRegularizer,
                     aggregator::AbstractAggregator,
                     consolidator::AbstractConsolidator; kw...)
        if nworkers() > 1
            @warn "There are worker processes, consider using distributed version of algorithm"
        end
        first_stage = StochasticPrograms.get_stage_one(stochasticprogram)
        length(x₀) != first_stage.numCols && error("Incorrect length of starting guess, has ", length(x₀), " should be ", first_stage.numCols)

        T = promote_type(eltype(x₀), Float32)
        c_ = convert(AbstractVector{T}, JuMP.prepAffObjective(first_stage))
        c_ *= first_stage.objSense == :Min ? 1 : -1
        x₀_ = convert(AbstractVector{T}, copy(x₀))
        mastervector = convert(AbstractVector{T}, copy(x₀))
        A = typeof(x₀_)
        SP = typeof(stochasticprogram)
        msolver = LQSolver(first_stage, mastersolver)
        M = typeof(msolver)
        S = LQSolver{typeof(MPB.LinearQuadraticModel(subsolver)),typeof(subsolver)}
        n = StochasticPrograms.nscenarios(stochasticprogram)
        feasibility = complete_recourse ? IgnoreFeasibility() : HandleFeasibility(T)
        F = typeof(feasibility)
        subproblems = Vector{SubProblem{F,T,A,S}}()
        load_subproblems!(subproblems, scenarioproblems(stochasticprogram), x₀_, subsolver)
        regularization = regularizer(x₀_)
        R = typeof(regularization)
        aggregation = aggregator(n, T)
        Agg = typeof(aggregation)
        consolidation = consolidator(T)
        C = typeof(consolidation)
        params = LShapedParameters{T}(; kw...)

        lshaped = new{T,A,SP,M,S,F,R,Agg,C}(stochasticprogram,
                                            LShapedData{T}(),
                                            params,
                                            msolver,
                                            mastervector,
                                            c_,
                                            x₀_,
                                            A(),
                                            n,
                                            subproblems,
                                            A(),
                                            feasibility,
                                            regularization,
                                            A(),
                                            Vector{SparseOptimalityCut{T}}(),
                                            aggregation,
                                            consolidation,
                                            A(),
                                            ProgressThresh(T(1.0), 0.0, "$(indentstr(params.indent))L-Shaped Gap "))
        # Initialize solver
        init!(lshaped)
        return lshaped
    end
end
LShaped(stochasticprogram::StochasticProgram,
        mastersolver::MPB.AbstractMathProgSolver,
        subsolver::MPB.AbstractMathProgSolver,
        complete_recourse::Bool,
        regularizer::AbstractRegularizer,
        aggregator::AbstractAggregator,
        consolidator::AbstractConsolidator; kw...) = LShaped(stochasticprogram,
                                                             rand(decision_length(stochasticprogram)),
                                                             mastersolver,
                                                             subsolver,
                                                             complete_recourse,
                                                             regularizer,
                                                             aggregator,
                                                             consolidator; kw...)

function init_solver!(lshaped::LShaped)
    append!(lshaped.subobjectives, zeros(nthetas(lshaped)))
    return lshaped
end

function load_subproblems!(subproblems::Vector{<:SubProblem{F,T,A}},
                           scenarioproblems::ScenarioProblems,
                           x::AbstractVector,
                           subsolver::MPB.AbstractMathProgSolver) where {F <: AbstractFeasibility,
                                                                         T <: AbstractFloat,
                                                                         A <: AbstractVector}
    for i = 1:StochasticPrograms.nscenarios(scenarioproblems)
        m = subproblem(scenarioproblems, i)
        y₀ = convert(A, rand(m.numCols))
        push!(subproblems, SubProblem(m,
                                      parentmodel(scenarioproblems),
                                      i,
                                      probability(scenario(scenarioproblems,i)),
                                      copy(x),
                                      y₀,
                                      subsolver,
                                      F))
    end
    return nothing
end

function load_subproblems!(subproblems::Vector{<:SubProblem{F,T,A}},
                           scenarioproblems::DScenarioProblems,
                           x::AbstractVector,
                           subsolver::MPB.AbstractMathProgSolver) where {F <: AbstractFeasibility,
                                                                         T <: AbstractFloat,
                                                                         A <: AbstractVector}
    for i = 1:StochasticPrograms.nscenarios(scenarioproblems)
        m = subproblem(scenarioproblems, i)
        y₀ = convert(A, rand(m.numCols))
        push!(subproblems,SubProblem(m,
                                     i,
                                     probability(scenario(scenarioproblems,i)),
                                     copy(x),
                                     y₀,
                                     masterterms(scenarioproblems,i),
                                     subsolver,
                                     F))
    end
    return nothing
end

function resolve_subproblems!(lshaped::LShaped{T}) where T <: AbstractFloat
    # Update subproblems
    update_subproblems!(lshaped.subproblems, lshaped.x)
    # Assume no cuts are added
    added = false
    # Solve sub problems
    for subproblem ∈ lshaped.subproblems
        cut::SparseHyperPlane{T} = subproblem()
        added |= aggregate_cut!(lshaped, lshaped.aggregation, cut)
    end
    added |= flush!(lshaped, lshaped.aggregation)
    # Return current objective value
    return current_objective_value(lshaped), added
end

function calculate_objective_value(lshaped::LShaped, x::AbstractVector)
    return lshaped.c⋅x + sum([subproblem.π*subproblem(x) for subproblem in lshaped.subproblems])
end

function fill_submodels!(lshaped::LShaped, scenarioproblems::ScenarioProblems)
    for (i, submodel) in enumerate(scenarioproblems.problems)
        lshaped.subproblems[i](decision(lshaped))
        fill_submodel!(submodel, lshaped.subproblems[i])
    end
    return nothing
end

function fill_submodels!(lshaped::LShaped, scenarioproblems::DScenarioProblems)
    j = 0
    @sync begin
        for w in workers()
            n = remotecall_fetch((sp)->length(fetch(sp).problems), w, scenarioproblems[w-1])
            for i in 1:n
                k = i+j
                lshaped.subproblems[k](decision(lshaped))
                @async remotecall_fetch((sp,i,x,μ,λ,C) -> fill_submodel!(fetch(sp).problems[i],x,μ,λ,C),
                                        w,
                                        scenarioproblems[w-1],
                                        i,
                                        get_solution(lshaped.subproblems[k])...)
            end
            j += n
        end
    end
    return nothing
end

function nthetas(lshaped::LShaped)
    return nthetas(lshaped.nscenarios, lshaped.aggregation)
end

function timestamp(lshaped::LShaped)
    return lshaped.data.iterations
end

function incumbent_decision(::LShaped, ::Integer, regularizer::AbstractRegularization)
    return regularizer.ξ
end

function incumbent_objective(::LShaped, ::Integer, regularizer::AbstractRegularization)
    return regularizer.data.Q̃
end

function incumbent_trustregion(::LShaped, ::Integer, rd::RegularizedDecomposition)
    return rd.data.σ
end

function incumbent_trustregion(::LShaped, ::Integer, tr::TrustRegion)
    return tr.data.Δ
end

# Consolidation functions
# ------------------------------------------------------------
function readd_cuts!(lshaped::LShaped, consolidation::Consolidation)
    for i in eachindex(consolidation.cuts)
        for cut in consolidation.cuts[i]
            add_cut!(lshaped, cut; consider_consolidation = false, check = false)
        end
        for cut in consolidation.feasibility_cuts[i]
            add_cut!(lshaped, cut; consider_consolidation = false, check = false)
        end
    end
    return nothing
end

function for_loadbalance(lshaped::LShaped, τ, miniter)
    nsubconstraints = length(subproblem(lshaped.stochasticprogram,1).linconstr)
    return lshaped.data.iterations >= (lshaped.data.consolidations+1)*miniter && nsubconstraints/ncutconstraints(lshaped) <= τ
end
# ------------------------------------------------------------

function iterate!(lshaped::LShaped)
    # Resolve all subproblems at the current optimal solution
    Q, added = resolve_subproblems!(lshaped)
    if Q == Inf && !handle_feasibility(lshaped.feasibility)
        @warn "Stochastic program is not second-stage feasible at the current decision. Rerun procedure with complete_recourse = false to use feasibility cuts."
        return :Infeasible
    end
    if Q == -Inf
        return :Unbounded
    end
    lshaped.data.Q = Q
    # Update the optimization vector
    take_step!(lshaped)
    # Resolve master
    status = solve_master!(lshaped)
    if status != :Optimal
        return status
    end
    # Update master solution
    update_solution!(lshaped)
    lshaped.data.θ = calculate_estimate(lshaped)
    # Log progress
    log!(lshaped)
    # Check optimality
    if check_optimality(lshaped) || (lshaped.regularizer isa NoRegularization && !added)
        # Optimal
        lshaped.data.Q = calculate_objective_value(lshaped,lshaped.x)
        push!(lshaped.Q_history,lshaped.data.Q)
        return :Optimal
    end
    # Project (if applicable)
    project!(lshaped)
    # Check optimality if level sets are used
    if lshaped.regularizer isa LevelSet
        lshaped.data.θ = calculate_estimate(lshaped)
        if check_optimality(lshaped)
            # Optimal
            lshaped.data.Q = calculate_objective_value(lshaped,lshaped.x)
            push!(lshaped.Q_history,lshaped.data.Q)
            return :Optimal
        end
    end
    # Consolidate (if applicable)
    consolidate!(lshaped, lshaped.consolidation)
    # Just return a valid status for this iteration
    return :Valid
end

function (lshaped::LShaped)()
    # Reset timer
    lshaped.progress.tfirst = lshaped.progress.tlast = time()
    # Start procedure
    while true
        status = iterate!(lshaped)
        if status != :Valid
            return status
        end
    end
end
