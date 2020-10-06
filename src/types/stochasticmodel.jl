"""
    StochasticModel

A mathematical model of a stochastic optimization problem.
"""
struct StochasticModel{N, P <: NTuple{N, StageParameters}}
    parameters::P
    generator::Function
    optimizer::StochasticProgramOptimizer

    function StochasticModel(generator::Function,
                             parameters::Vararg{StageParameters,N}) where N
        return new{N,typeof(parameters)}(parameters, generator, StochasticProgramOptimizer(nothing))
    end
end
nstages(::StochasticModel{N}) where N = N
"""
    @stochastic_model(def)

Define a stochastic model capable of instantiating stochastic programs, using the syntax
```julia
sm = @stochastic_model begin
    ...
    @stage x begin
      ...
    end
    ...
end
```
where the inner blocks are [`@stage`](@ref) blocks. At least two stages must be specified in consecutive order. A stochastic model object can later be used to [`instantiate`](@ref) stochastic programs using a given set of scenarios or by using samplers.

## Examples

The following defines a stochastic model consisitng of the first stage model given by:
```math
  minimize 100x₁ + 150x₂
    s.t  x₁ + x₂ ≤ 120
         x₁ ≥ 40
         x₂ ≥ 20
```
and the second-stage model given by:
```math
  minimize q₁(ξ)y₁ + q₂(ξ)y₂
    s.t  6y₁ + 10y₂ ≤ 60x₁
         8y₁ + 5y₂ ≤ 60x₂
         0 ≤ y₁ ≤ d₁(ξ)
         0 ≤ y₂ ≤ d₂(ξ)
```
where ``q₁(ξ), q₂(ξ), d₁(ξ), d₂(ξ)`` depend on the scenario ``ξ``.

```julia
sm = @stochastic_model begin
    @stage 1 begin
        @decision(model, x₁ >= 40)
        @decision(model, x₂ >= 20)
        @objective(model, Min, 100*x₁ + 150*x₂)
        @constraint(model, x₁ + x₂ <= 120)
    end
    @stage 2 begin
        @decision x₁ x₂
        @uncertain q₁ q₂ d₁ d₂
        @variable(model, 0 <= y₁ <= d₁)
        @variable(model, 0 <= y₂ <= d₂)
        @objective(model, Min, q₁*y₁ + q₂*y₂)
        @constraint(model, 6*y₁ + 10*y₂ <= 60*x₁)
        @constraint(model, 8*y₁ + 5*y₂ <= 80*x₂)
    end
end
```

See also: [`@stage`](@ref), [`@parameters`](@ref), [`@decision`](@ref), [`@uncertain`](@ref)
"""
macro stochastic_model(def)
    stage = 0
    scenariodef = Expr(:block)
    paramdefs = Vector{Expr}()
    decisiondefs = Vector{Vector{Symbol}}()
    def = prewalk(def) do x
        x = if @capture(x, @stage n_ arg_)
            if @capture(arg, sp_ = def_)
                x
            else
                stage == 0 && (n == 1 || error("A first stage must be defined."))
                stage == n - 1 || error("Define the stages in coherent order.")
                stage += 1
                push!(paramdefs, :(StageParameters()))
                push!(decisiondefs, Vector{Symbol}())
                if n > 1
                    pushfirst!(arg.args, :(@known $(decisiondefs[n-1]...)))
                end
                return :(@stage $n sp = $arg)
            end
        else
            x
        end
        paramdef = if @capture(x, @parameters arg_)
            names = Vector{Symbol}()
            default = Vector{Expr}()
            for paramdef in block(prettify(arg)).args
                if @capture(paramdef, key_Symbol = val_)
                    push!(names, key)
                    push!(default, paramdef)
                elseif @capture(paramdef, key_Symbol)
                    push!(names, key)
                else
                    @show paramdef
                    error("Incorrect @parameters syntax. Specify parameter names, possibly with a default value.")
                end
            end
            :(StageParameters($names; $(default...)))
        elseif @capture(x, @parameters args__)
            args = convert(Vector{Symbol}, args)
            :(StageParameters($args))
        else
            nothing
        end
        if paramdef != nothing
            paramdefs[stage] = paramdef
        end
        if @capture(x, @decision arg__)
            if @capture(x, @decision model_ var_Symbol more__) || @capture(x, @decision model_ var_Symbol[range__] more__) ||
               @capture(x, @decision model_ var_Symbol <= ub_ more__) || @capture(x, @decision model_ var_Symbol >= lb_ more__) ||
               @capture(x, @decision model_ var_Symbol[range__] <= ub_ more__) || @capture(x, @decision model_ var_Symbol[range__] >= ln_ more__) ||
               @capture(x, @decision model_ var_Symbol in set_ more__) || @capture(x, @decision model_ var_Symbol[range__] in set_ more__) ||
               @capture(x, @decision model_ lb_ <= var_Symbol <= ub_ more__) || @capture(x, @decision model_ lb_ <= var_Symbol[range__] <= ub_ more__)
                push!(decisiondefs[stage], var)
            end
        end
        scenariodef = if @capture(x, @uncertain var_Symbol::t_Symbol = def_)
            esc(@q begin
                @scenario $t = $def
            end)
        else
            scenariodef
        end
        return x
    end
    stage >= 2 || error("Define at least two stages.")
    code = @q begin
        $scenariodef
        StochasticModel($(esc.(paramdefs)...)) do $(esc(:sp))
            $(esc(def))
        end
    end
    return code
end

# Printing #
# ========================== #
function Base.show(io::IO, stochasticmodel::StochasticModel)
    println(io, "Multi-stage Stochastic Model")
end
function Base.show(io::IO, stochasticmodel::StochasticModel{2})
    modelstr = "minimize f₀(x) + 𝔼[f(x,ξ)]
  x∈𝒳

where

f(x,ξ) = min  f(y; x, ξ)
              y ∈ 𝒴 (x, ξ)"
    print(io, "Two-Stage Stochastic Model\n\n")
    println(io, modelstr)
end

# Getters #
# ========================== #
"""
    optimal_instance(stochasticmodel::StochasticModel)

Return a stochastic programming instance of the stochastic model after a call to [`optimize!`](@ref).
"""
function optimal_instance(stochasticmodel::StochasticModel)
    # Sanity checks
    check_provided_optimizer(stochasticmodel.optimizer)
    if MOI.get(stochasticmodel, MOI.TerminationStatus()) == MOI.OPTIMIZE_NOT_CALLED
        throw(OptimizeNotCalled())
    end
    return optimal_instance(optimizer(stochasticmodel))
end

# MOI #
# ========================== #
function MOI.get(stochasticmodel::StochasticModel, attr::Union{MOI.TerminationStatus, MOI.PrimalStatus, MOI.DualStatus})
    return MOI.get(optimizer(stochasticmodel), attr)
end
function MOI.get(stochasticmodel::StochasticModel, attr::MOI.AbstractModelAttribute)
    if MOI.is_set_by_optimize(attr)
        check_provided_optimizer(stochasticmodel.optimizer)
        if MOI.get(stochasticmodel, MOI.TerminationStatus()) == MOI.OPTIMIZE_NOT_CALLED
            throw(OptimizeNotCalled())
        end
    end
    return MOI.get(optimizer(stochasticmodel), attr)
end
function MOI.get(stochasticmodel::StochasticModel, attr::MOI.AbstractOptimizerAttribute)
    MOI.get(optimizer(stochasticmodel), attr)
end

MOI.set(sp::StochasticModel, attr::MOI.AbstractOptimizerAttribute, value) = MOI.set(optimizer(sp), attr, value)
MOI.set(sp::StochasticModel, attr::MOI.AbstractModelAttribute, value) = MOI.set(optimizer(sp), attr, value)
