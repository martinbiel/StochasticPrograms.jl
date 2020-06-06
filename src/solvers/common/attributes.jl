struct RelativeTolerance <: AbstractStructuredOptimizerAttribute end

struct MasterOptimizer <: AbstractStructuredOptimizerAttribute end

function JuMP.set_optimizer_attribute(stochasticprogram::StochasticProgram, attr::MasterOptimizer, value)
    MOI.set(stochasticprogram, attr, value)
    set_master_optimizer!(structure(stochasticprogram), value)
end

struct SubproblemOptimizer <: AbstractStructuredOptimizerAttribute end

function JuMP.set_optimizer_attribute(stochasticprogram::StochasticProgram, attr::SubproblemOptimizer, value)
    MOI.set(stochasticprogram, attr, value)
    set_subproblem_optimizer!(structure(stochasticprogram), value)
end

struct Execution <: AbstractStructuredOptimizerAttribute end

abstract type ExecutionParameter <: AbstractStructuredOptimizerAttribute end
