# Structured optimizer attributes #
# ========================== #
struct RelativeTolerance <: AbstractStructuredOptimizerAttribute end

struct MasterOptimizer <: AbstractStructuredOptimizerAttribute end

function JuMP.set_optimizer_attribute(stochasticprogram::StochasticProgram, attr::MasterOptimizer, value)
    MOI.set(stochasticprogram, attr, value)
    set_master_optimizer!(structure(stochasticprogram), value)
end

struct RawMasterOptimizerParameter <: AbstractStructuredOptimizerAttribute
    name::Any
end

function set_masteroptimizer_attribute(stochasticprogram::StochasticProgram, name::Union{Symbol, String}, value)
    return set_optimizer_attribute(stochasticprogram, RawMasterOptimizerParameter(String(name)), value)
end
function set_masteroptimizer_attributes(stochasticprogram::StochasticProgram, pairs::Pair...)
    for (name, value) in pairs
        set_masteroptimizer_attributes(stochasticprogram, name, value)
    end
end
function set_masteroptimizer_attributes(stochasticprogram::StochasticProgram; kw...)
    for (name, value) in kw
        set_masteroptimizer_attributes(stochasticprogram, name, value)
    end
end

struct SubproblemOptimizer <: AbstractStructuredOptimizerAttribute end

function JuMP.set_optimizer_attribute(stochasticprogram::StochasticProgram, attr::SubproblemOptimizer, value)
    MOI.set(stochasticprogram, attr, value)
    set_subproblem_optimizer!(structure(stochasticprogram), value)
end

struct RawSubproblemOptimizerParameter <: AbstractStructuredOptimizerAttribute
    name::Any
end

function set_suboptimizer_attribute(stochasticprogram::StochasticProgram, name::Union{Symbol, String}, value)
    return set_optimizer_attribute(stochasticprogram, RawMasterOptimizerParameter(String(name)), value)
end
function set_suboptimizer_attributes(stochasticprogram::StochasticProgram, pairs::Pair...)
    for (name, value) in pairs
        set_suboptimizer_attributes(stochasticprogram, name, value)
    end
end
function set_suboptimizer_attributes(stochasticprogram::StochasticProgram; kw...)
    for (name, value) in kw
        set_suboptimizer_attributes(stochasticprogram, name, value)
    end
end

struct Execution <: AbstractStructuredOptimizerAttribute end

abstract type ExecutionParameter <: AbstractStructuredOptimizerAttribute end


# Sampled optimizer attributes #
# ========================== #
struct Confidence <: AbstractSampledOptimizerAttribute end

struct NumSamples <: AbstractSampledOptimizerAttribute end

struct NumEvalSamples <: AbstractSampledOptimizerAttribute end

struct NumEWSSamples <: AbstractSampledOptimizerAttribute end

struct NumEEVSamples <: AbstractSampledOptimizerAttribute end

struct NumLowerTrials <: AbstractSampledOptimizerAttribute end

struct NumUpperTrials <: AbstractSampledOptimizerAttribute end

struct InstanceOptimizer <: AbstractSampledOptimizerAttribute end

struct RawInstanceOptimizerParameter <: AbstractSampledOptimizerAttribute
    name::Any
end
MOI.supports(::MOI.AbstractOptimizer, ::RawInstanceOptimizerParameter) = false

function set_instanceoptimizer_attribute(stochasticmodel::StochasticModel, attr::MOI.AbstractOptimizerAttribute, value)
    return MOI.set(optimizer(stochasticmodel), InstanceOptimizer(), attr, value)
end
function set_instanceoptimizer_attribute(stochasticmodel::StochasticModel, name::Union{Symbol, String}, value)
    return set_optimizer_attribute(stochasticmodel, RawInstanceOptimizerParameter(String(name)), value)
end
function set_instanceoptimizer_attributes(stochasticmodel::StochasticModel, pairs::Pair...)
    for (name, value) in pairs
        set_instanceoptimizer_attribute(stochasticmodel, name, value)
    end
end
function set_instanceoptimizer_attributes(stochasticmodel::StochasticModel; kw...)
    for (name, value) in kw
        set_instanceoptimizer_attribute(stochasticmodel, name, value)
    end
end
