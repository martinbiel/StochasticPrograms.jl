abstract type AbstractFeasibility end

initialize_feasibility!(lshaped::AbstractLShapedSolver) = initialize_feasibility!(lshaped, lshaped.feasibility)
update_objective!(lshaped::AbstractLShapedSolver, cut::AbstractHyperPlane) = update_objective!(lshaped, cut, lshaped.feasibility)
active_model_objectives(lshaped::AbstractLShapedSolver) = active_model_objectives(lshaped, lshaped.feasibility)

# Fallback for objective update
update_objective!(lshaped::AbstractLShapedSolver, cut::AbstractHyperPlane, ::AbstractFeasibility) = nothing

struct IgnoreFeasibility <: AbstractFeasibility end

initialize_feasibility!(::AbstractLShapedSolver, ::IgnoreFeasibility) = nothing
active_model_objectives(lshaped::AbstractLShapedSolver, ::IgnoreFeasibility) = fill(true, nthetas(lshaped))
handle_feasibility(::IgnoreFeasibility) = false
initial_theta_coefficient(::IgnoreFeasibility) = 1.0
ncuts(::IgnoreFeasibility) = 0

struct HandleFeasibility{T <: AbstractFloat} <: AbstractFeasibility
    active_model_objectives::Vector{Bool}
    cuts::Vector{SparseFeasibilityCut{T}}

    function HandleFeasibility(::Type{T}) where T <: AbstractFloat
        return new{T}(Vector{Bool}(), Vector{SparseFeasibilityCut{T}}())
    end
end

function initialize_feasibility!(lshaped::AbstractLShapedSolver, feasibility::HandleFeasibility)
    append!(feasibility.active_model_objectives, fill(false, nthetas(lshaped)))
end

function active_model_objectives(::AbstractLShapedSolver, feasibility::HandleFeasibility)
    return feasibility.active_model_objectives
end

function update_objective!(lshaped::AbstractLShapedSolver, cut::HyperPlane{OptimalityCut}, feasibility::HandleFeasibility)
    # Ensure that θi is included in minimization if feasibility cuts are used
    c = MPB.getobj(lshaped.mastersolver.lqmodel)
    if c[length(lshaped.x) + cut.id] == 0.0
        c[length(lshaped.x) + cut.id] = 1.0
        feasibility.active_model_objectives[cut.id] = true
        MPB.setobj!(lshaped.mastersolver.lqmodel,c)
    end
    return nothing
end
function update_objective!(lshaped::AbstractLShapedSolver, cut::AggregatedOptimalityCut, feasibility::HandleFeasibility)
    # Ensure that θis are included in minimization if feasibility cuts are used
    c = MPB.getobj(lshaped.mastersolver.lqmodel)
    ids = filter(i->c[length(lshaped.x)+i] == 0.0, cut.ids)
    if !isempty(ids)
        c[length(lshaped.x) .+ ids] .= 1.0
        feasibility.active_model_objectives[ids] .= true
        MPB.setobj!(lshaped.mastersolver.lqmodel,c)
    end
    return nothing
end

handle_feasibility(::HandleFeasibility) = true
initial_theta_coefficient(::HandleFeasibility) = 0.0
ncuts(feasibility::HandleFeasibility) = length(feasibility.cuts)
