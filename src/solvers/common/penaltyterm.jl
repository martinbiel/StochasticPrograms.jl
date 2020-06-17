abstract type AbstractPenaltyterm end
const L2NormConstraint = CI{QuadraticDecisionFunction{Float64,QuadraticPart{Float64}}, MOI.LessThan{Float64}}
const LinearizationConstraint = CI{QuadraticDecisionFunction{Float64,LinearPart{Float64}}, MOI.LessThan{Float64}}
const InfNormConstraint = CI{VectorAffineDecisionFunction{Float64}, MOI.NormInfinityCone}
const ManhattanNormConstraint = CI{VectorAffineDecisionFunction{Float64}, MOI.NormOneCone}

Base.copy(::PT) where PT <: AbstractPenaltyterm = PT()

"""
    Quadratic

Functor object for using a quadratic 2-norm penalty term. Requires an `AbstractMathProgSolver` capable of solving QP problems. Passed by default through `penalty` where applicable.

"""
mutable struct Quadratic <: AbstractPenaltyterm
    t::MOI.VariableIndex
    constraint::L2NormConstraint

    Quadratic() = new(MOI.VariableIndex(0), L2NormConstraint(0))
end

function initialize_penaltyterm!(penalty::Quadratic,
                                 model::MOI.AbstractOptimizer,
                                 α::AbstractFloat,
                                 x::Vector{MOI.VariableIndex},
                                 ξ::Vector{MOI.VariableIndex})
    T = typeof(α)
    n = length(x) + 1
    # Get current objective
    F = MOI.get(model, MOI.ObjectiveFunctionType())
    f = MOI.get(model, MOI.ObjectiveFunction{F}())
    # Check if quadratic constraint is supported
    F = MOI.ScalarQuadraticFunction{Float64}
    quad_support = MOI.supports_constraint(model, MOI.ScalarQuadraticFunction{Float64}, MOI.LessThan{Float64})
    if !quad_support
        throw(MOI.UnsupportedAttribute(MOI.ConstraintFunction(), "Using a quadratic penalty term requires an optimizer that supports quadratic constraints"))
    end
    # Add ℓ₂-norm auxilliary variable
    penalty.t = MOI.add_variable(model)
    t = MOI.SingleVariable(penalty.t)
    # Prepare variable vectors
    x = VectorOfDecisions(x)
    ξ = VectorOfKnowns(ξ)
    # Set name
    MOI.set(model, MOI.VariableName(), penalty.t, "‖x - ξ‖₂²")
    # Add quadratic ℓ₂-norm constraint
    g = MOIU.operate(-, T, x, ξ)
    g = LinearAlgebra.dot(g, g)
    MOIU.operate!(-, T, g, t)
    penalty.constraint =
        MOI.add_constraint(model, g,
                           MOI.LessThan(0.0))
    # Add sense-corrected aux term to objective
    F = MOI.get(model, MOI.ObjectiveFunctionType())
    sense = MOI.get(model, MOI.ObjectiveSense())
    correction = (sense == MOI.MIN_SENSE || sense == MOI.FEASIBILITY_SENSE) ? 1.0 : -1.0
    MOI.modify(model,
               MOI.ObjectiveFunction{F}(),
               MOI.ScalarCoefficientChange(penalty.t, correction * α))
    return nothing
end

function update_penaltyterm!(penalty::Quadratic,
                             model::MOI.AbstractOptimizer,
                             α::AbstractFloat,
                             x::Vector{MOI.VariableIndex},
                             ξ::Vector{MOI.VariableIndex})
    # Update penalty parameter
    F = MOI.get(model, MOI.ObjectiveFunctionType())
    sense = MOI.get(model, MOI.ObjectiveSense())
    correction = (sense == MOI.MIN_SENSE || sense == MOI.FEASIBILITY_SENSE) ? 1.0 : -1.0
    MOI.modify(model,
               MOI.ObjectiveFunction{F}(),
               MOI.ScalarCoefficientChange(penalty.t, correction * α))
    # Update projection targets
    MOI.modify(model,
               penalty.constraint,
               KnownValuesChange())
    return nothing
end

function remove_penalty!(penalty::Quadratic,
                         model::MOI.AbstractOptimizer)
    # Delete ℓ₂-norm constraint
    if !iszero(penalty.constraint.value)
        MOI.delete(model, penalty.constraint)
        penalty.constraint = L2NormConstraint(0)
    end
    # Delete aux variable
    if !iszero(penalty.t.value)
        MOI.delete(model, penalty.t)
        penalty.t = MOI.VariableIndex(0)
    end
    return nothing
end

"""
    Linearized

Functor object for using an approximately quadratic penalty term, through linearization. Pass through `penalty` where applicable.

...
# Parameters
- `nbreakpoints::Int`: Number of cutting planes used to approximate quadratic term
...
"""
mutable struct Linearized <: AbstractPenaltyterm
    num_breakpoints::Int
    spacing::Float64
    auxilliary_variables::Vector{MOI.VariableIndex}
    constraints::Vector{LinearizationConstraint}

    function Linearized(num_breakpoints::Integer, spacing::Float64)
        n = num_breakpoints >= 3 ? num_breakpoints : 3
        spacing = spacing >= eps() ? spacing : 1.0
        return new(num_breakpoints,
                   spacing,
                   MOI.VariableIndex[],
                   LinearizationConstraint[])
    end
end
Linearized(; num_breakpoints = 3, spacing = 1.0) = Linearized(num_breakpoints, spacing)
Base.copy(linearized::Linearized) = Linearized(linearized.num_breakpoints, linearized.spacing)

function initialize_penaltyterm!(penalty::Linearized,
                                 model::MOI.AbstractOptimizer,
                                 α::AbstractFloat,
                                 x::Vector{MOI.VariableIndex},
                                 ξ::Vector{MOI.VariableIndex})
    T = typeof(α)
    n = length(x)
    m = penalty.num_breakpoints
    resize!(penalty.auxilliary_variables, n)
    resize!(penalty.constraints, n * m)
    F = MOI.get(model, MOI.ObjectiveFunctionType())
    # Add auxilliary cost variables
    for i in eachindex(x)
        penalty.auxilliary_variables[i] = MOI.add_variable(model)
        var = penalty.auxilliary_variables[i]
        MOI.add_constraint(model, MOI.SingleVariable(var), MOI.GreaterThan(0.0))
        name = add_subscript("‖x - ξ‖₂²", i)
        MOI.set(model, MOI.VariableName(), var, name)
    end
    # Add `num_breakpoints` linearization constraints
    # as tangent planes placed uniform around `penalty.spacing`
    # multiplied by the current incumbent `ξ`
    breakpoints = map(1:m) do i
        2*penalty.spacing*(i-1)/(m-1)
    end .- (penalty.spacing - 1)
    k = 1
    for i in eachindex(x)
        tᵢ = MOI.SingleVariable(penalty.auxilliary_variables[i])
        xᵢ = SingleDecision(x[i])
        ξᵢ = SingleKnown(ξ[i])
        for (j,r) in enumerate(breakpoints)
            # Add linearization constraint
            g = MOIU.operate(-, T, xᵢ, r * ξᵢ)
            ∇f = MOIU.operate(*, T, 2*(r - 1), ξᵢ)
            g = MOIU.operate(*, T, ∇f, g)
            f = MOIU.operate(*, T, r - 1, ξᵢ)
            f = MOIU.operate(*, T, f, f)
            MOIU.operate!(+, T, g, f)
            MOIU.operate!(-, T, g, tᵢ)
            penalty.constraints[k] =
                MOI.add_constraint(model,
                                   g,
                                   MOI.LessThan(0.0))
            k += 1
        end
    end
    # Add sense-corrected aux term to objective
    F = MOI.get(model, MOI.ObjectiveFunctionType())
    sense = MOI.get(model, MOI.ObjectiveSense())
    correction = (sense == MOI.MIN_SENSE || sense == MOI.FEASIBILITY_SENSE) ? 1.0 : -1.0
    for i in eachindex(x)
        MOI.modify(model,
                   MOI.ObjectiveFunction{F}(),
                   MOI.ScalarCoefficientChange(penalty.auxilliary_variables[i],
                                               correction * α))
    end
    return nothing
end

function update_penaltyterm!(penalty::Linearized,
                             model::MOI.AbstractOptimizer,
                             α::AbstractFloat,
                             x::Vector{MOI.VariableIndex},
                             ξ::Vector{MOI.VariableIndex})
    # Update penalty parameter
    F = MOI.get(model, MOI.ObjectiveFunctionType())
    sense = MOI.get(model, MOI.ObjectiveSense())
    correction = (sense == MOI.MIN_SENSE || sense == MOI.FEASIBILITY_SENSE) ? 1.0 : -1.0
    for i in eachindex(x)
        MOI.modify(model,
                   MOI.ObjectiveFunction{F}(),
                   MOI.ScalarCoefficientChange(penalty.auxilliary_variables[i], correction * α))
    end
    # Update projection target
    for constraint in penalty.constraints
        MOI.modify(model,
                   constraint,
                   KnownValuesChange())
    end
    return nothing
end

function remove_penalty!(penalty::Linearized,
                         model::MOI.AbstractOptimizer)
    # Delete linearization constraints
    for (i,constraint) in enumerate(penalty.constraints)
        if !iszero(constraint.value)
            MOI.delete(model, constraint)
            penalty.constraints[i] = LinearizationConstraint(0)
        end
    end
    # Delete aux variables
    for (i,var) in enumerate(penalty.auxilliary_variables)
        if !iszero(var.value)
            MOI.delete(model, var)
            penalty.auxilliary_variables[i] = MOI.VariableIndex(0)
        end
    end
    return nothing
end

"""
    InfNorm

Functor object for using a linear ∞-norm penalty term. Pass through `penalty` where applicable.

"""
mutable struct InfNorm <: AbstractPenaltyterm
    t::MOI.VariableIndex
    constraint::InfNormConstraint

    InfNorm() = new(MOI.VariableIndex(0), InfNormConstraint(0))
end

function initialize_penaltyterm!(penalty::InfNorm,
                                 model::MOI.AbstractOptimizer,
                                 α::AbstractFloat,
                                 x::Vector{MOI.VariableIndex},
                                 ξ::Vector{MOI.VariableIndex})
    T = typeof(α)
    n = length(x) + 1
    # Add ∞-norm auxilliary variable
    penalty.t = MOI.add_variable(model)
    MOI.set(model, MOI.VariableName(), penalty.t, "||x - ξ||_∞")
    x = VectorOfDecisions(x)
    ξ = VectorOfKnowns(ξ)
    t = MOI.SingleVariable(penalty.t)
    # Add ∞-norm constraint
    f = MOIU.operate(vcat, T, t, x) -
        MOIU.operate(vcat, T, zero(α), ξ)
    penalty.constraint =
        MOI.add_constraint(model, f,
                           MOI.NormInfinityCone(n))
    # Add sense-corrected aux term to objective
    F = MOI.get(model, MOI.ObjectiveFunctionType())
    sense = MOI.get(model, MOI.ObjectiveSense())
    correction = (sense == MOI.MIN_SENSE || sense == MOI.FEASIBILITY_SENSE) ? 1.0 : -1.0
    MOI.modify(model,
               MOI.ObjectiveFunction{F}(),
               MOI.ScalarCoefficientChange(penalty.t, correction * α))
    return nothing
end

function update_penaltyterm!(penalty::InfNorm,
                             model::MOI.AbstractOptimizer,
                             α::AbstractFloat,
                             x::Vector{MOI.VariableIndex},
                             ξ::Vector{MOI.VariableIndex})
    # Update penalty parameter
    F = MOI.get(model, MOI.ObjectiveFunctionType())
    sense = MOI.get(model, MOI.ObjectiveSense())
    correction = (sense == MOI.MIN_SENSE || sense == MOI.FEASIBILITY_SENSE) ? 1.0 : -1.0
    MOI.modify(model,
               MOI.ObjectiveFunction{F}(),
               MOI.ScalarCoefficientChange(penalty.t, correction * α))
    # Update projection targets
    MOI.modify(model,
               penalty.constraint,
               KnownValuesChange())
    return nothing
end

function remove_penalty!(penalty::InfNorm,
                         model::MOI.AbstractOptimizer)
    # Delete ∞-norm constraint
    if !iszero(penalty.constraint.value)
        MOI.delete(model, penalty.constraint)
        penalty.constraint = InfNormConstraint(0)
    end
    # Delete aux variable
    if !iszero(penalty.t.value)
        MOI.delete(model, penalty.t)
        penalty.t = MOI.VariableIndex(0)
    end
    return nothing
end

"""
    ManhattanNorm

Functor object for using a linear 1-norm penalty term. Pass through `penalty` where applicable.

"""
mutable struct ManhattanNorm <: AbstractPenaltyterm
    t::MOI.VariableIndex
    constraint::ManhattanNormConstraint

    ManhattanNorm() = new(MOI.VariableIndex(0), ManhattanNormConstraint(0))
end

function initialize_penaltyterm!(penalty::ManhattanNorm,
                                 model::MOI.AbstractOptimizer,
                                 α::AbstractFloat,
                                 x::Vector{MOI.VariableIndex},
                                 ξ::Vector{MOI.VariableIndex})
    T = typeof(α)
    n = length(x) + 1
    # Add ∞-norm auxilliary variable
    penalty.t = MOI.add_variable(model)
    MOI.set(model, MOI.VariableName(), penalty.t, "‖x - ξ‖₁")
    x = VectorOfDecisions(x)
    ξ = VectorOfKnowns(ξ)
    t = MOI.SingleVariable(penalty.t)
    # Add ∞-norm constraint
    f = MOIU.operate(vcat, T, t, x) -
        MOIU.operate(vcat, T, zero(α), ξ)
    penalty.constraint =
        MOI.add_constraint(model, f,
                           MOI.NormOneCone(n))
    # Add sense-corrected aux term to objective
    F = MOI.get(model, MOI.ObjectiveFunctionType())
    sense = MOI.get(model, MOI.ObjectiveSense())
    correction = (sense == MOI.MIN_SENSE || sense == MOI.FEASIBILITY_SENSE) ? 1.0 : -1.0
    MOI.modify(model,
               MOI.ObjectiveFunction{F}(),
               MOI.ScalarCoefficientChange(penalty.t, correction * α))
    return nothing
end

function update_penaltyterm!(penalty::ManhattanNorm,
                             model::MOI.AbstractOptimizer,
                             α::AbstractFloat,
                             x::Vector{MOI.VariableIndex},
                             ξ::Vector{MOI.VariableIndex})
    # Update penalty parameter
    F = MOI.get(model, MOI.ObjectiveFunctionType())
    sense = MOI.get(model, MOI.ObjectiveSense())
    correction = (sense == MOI.MIN_SENSE || sense == MOI.FEASIBILITY_SENSE) ? 1.0 : -1.0
    MOI.modify(model,
               MOI.ObjectiveFunction{F}(),
               MOI.ScalarCoefficientChange(penalty.t, correction * α))
    # Update projection targets
    MOI.modify(model,
               penalty.constraint,
               KnownValuesChange())
    return nothing
end

function remove_penalty!(penalty::ManhattanNorm,
                         model::MOI.AbstractOptimizer)
    # Delete ∞-norm constraint
    if !iszero(penalty.constraint.value)
        MOI.delete(model, penalty.constraint)
        penalty.constraint = ManhattanNormConstraint(0)
    end
    # Delete aux variable
    if !iszero(penalty.t.value)
        MOI.delete(model, penalty.t)
        penalty.t = MOI.VariableIndex(0)
    end
    return nothing
end
