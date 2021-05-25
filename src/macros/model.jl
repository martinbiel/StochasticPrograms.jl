"""
    @stochastic_model(def)

Define a stochastic model capable of instantiating stochastic programs, using the syntax
```julia
@stochastic_model model_name begin
    ...
    @stage x begin
      ...
    end
    ...
end
```
where the inner blocks are [`@stage`](@ref) blocks. At least two stages must be specified in consecutive order. A stochastic model object can later be used to [`instantiate`](@ref) stochastic programs using a given set of scenarios or by using samplers. The model is referenced using `model_name` in the [`@stage`](@ref) blocks. If `model_name` is left out, the macro returns an anonymous model object, and the reserved keyword `model` must be used in the [`@stage`](@ref) blocks. Otherwise, the resulting stochastic model object is stored in a variable named `model_name`.

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
@stochastic_model sm begin
    @stage 1 begin
        @decision(sm, x₁ >= 40)
        @decision(sm, x₂ >= 20)
        @objective(sm, Min, 100*x₁ + 150*x₂)
        @constraint(sm, x₁ + x₂ <= 120)
    end
    @stage 2 begin
        @decision x₁ x₂
        @uncertain q₁ q₂ d₁ d₂
        @variable(sm, 0 <= y₁ <= d₁)
        @variable(sm, 0 <= y₂ <= d₂)
        @objective(sm, Min, q₁*y₁ + q₂*y₂)
        @constraint(sm, 6*y₁ + 10*y₂ <= 60*x₁)
        @constraint(sm, 8*y₁ + 5*y₂ <= 80*x₂)
    end
end
```
or alternatively using anonymous syntax:
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
where the reserved keyword `model` is used throughout.

See also: [`@stage`](@ref), [`@parameters`](@ref), [`@decision`](@ref), [`@uncertain`](@ref)
"""
macro stochastic_model(args...)
    model_name, def = if length(args) == 1
        model_name = :model
        def = args[1]
        model_name, def
    else
        model_name = args[1]
        def = args[2]
        model_name, def
    end
    _error(x, str...) = begin
        macroname = Symbol(String(x.args[1])[2:end])
        JuMP._macro_error(macroname, prettify.(x.args[3:end]), x.args[2], str...)
    end
    stage = 0
    scenariodef = Expr(:block)
    paramdefs = Vector{Expr}()
    decisiondefs = Vector{Vector{Symbol}}()
    # Count stages
    N = 0
    prewalk(def) do x
        if @capture(x, @stage n_ arg_)
            N += 1
        end
        return x
    end
    modeldef = prewalk(def) do x
        x = if @capture(x, @stage n_ arg_)
            if @capture(arg, sp_ = stagedef_)
                x
            else
                stage += 1
                stage == n || _error(x, "Define the stages in coherent order. Expected stage $(stage) here.")
                push!(paramdefs, :(StageParameters()))
                push!(decisiondefs, Vector{Symbol}())
                if n > 1
                    pushfirst!(arg.args, :(@known $model_name $(decisiondefs[n-1]...)))
                end
                return :(@stage $n $model_name = $arg)
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
                    _error(x, "Incorrect @parameters syntax. Specify parameter names, possibly with a default value.")
                end
            end
            code = :(StageParameters($names; $(default...)))
            Expr(:block, x.args[2], code)
        elseif @capture(x, @parameters arg__)
            names = Vector{Symbol}()
            default = Vector{Expr}()
            for paramdef in arg
                if @capture(paramdef, key_Symbol = val_)
                    push!(names, key)
                    push!(default, paramdef)
                elseif @capture(paramdef, key_Symbol)
                    push!(names, key)
                else
                    _error(x, "Incorrect @parameters syntax. Specify parameter names, possibly with a default value.")
                end
            end
            code = :(StageParameters($names; $(default...)))
            Expr(:block, x.args[2], code)
        else
            nothing
        end
        if paramdef != nothing
            paramdefs[stage] = paramdef
        end
        if @capture(x, @decision arg__)
            stage < N || _error(x, "@decision declarations cannot be used in the final stage. Consider @recourse instead.")
            if @capture(x, @decision model_ var_Symbol more__) || @capture(x, @decision model_ var_Symbol[range__] more__) ||
               @capture(x, @decision model_ var_Symbol <= ub_ more__) || @capture(x, @decision model_ var_Symbol >= lb_ more__) ||
               @capture(x, @decision model_ var_Symbol[range__] <= ub_ more__) || @capture(x, @decision model_ var_Symbol[range__] >= ln_ more__) ||
               @capture(x, @decision model_ var_Symbol in set_ more__) || @capture(x, @decision model_ var_Symbol[range__] in set_ more__) ||
               @capture(x, @decision model_ lb_ <= var_Symbol <= ub_ more__) || @capture(x, @decision model_ lb_ <= var_Symbol[range__] <= ub_ more__)
                push!(decisiondefs[stage], var)
            end
        end
        if @capture(x, @recourse arg__)
            stage == N || _error(x, "@recourse declarations can only be used in the final stage.")
        end
        if @capture(x, @uncertain arg__)
            stage == 1 && _error(x, "@uncertain declarations cannot be used in the first stage.")
        end
        scenariodef = if @capture(x, @uncertain var_Symbol::t_Symbol = scendef_)
            esc(@q begin
                @scenario $t = $scendef
            end)
        else
            scenariodef
        end
        return x
    end
    stage >= 2 || JuMP._macro_error(:stochastic_model, prettify.(def.args[2:end]), __source__, "Define at least two stages.")
    code = if length(args) == 1
        # anonymous model, return resulting expression
        code = @q begin
            $scenariodef
            StochasticModel($(esc.(paramdefs)...)) do $(esc(model_name))
                $(esc(modeldef))
            end
        end
    else
        # model name given, assign resulting expression to model object
        code = @q begin
            $scenariodef
            $(esc(model_name)) = StochasticModel($(esc.(paramdefs)...)) do $(esc(model_name))
                $(esc(modeldef))
            end
        end
    end
    return code
end
