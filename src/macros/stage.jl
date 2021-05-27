"""
    @stage(def)

Add a stage model generation recipe to `stochasticprogram` using the syntax
```julia
@stage stage stochasticprogram::StochasticProgram = begin
    @parameters param1 param2 ...
    @decision(stochasticprogram, var) ...
    @uncertain ξ
    ... JuMPdef ...
    ...
end
```
where `stage` is the stage number and JuMP syntax is used inside the block to define the stage model. During definition, the stage model is referenced using the same variable name as `stochasticprogram`.

## Examples

The following defines the first stage model given by:
```math
  minimize 100x₁ + 150x₂
    s.t  x₁ + x₂ ≤ 120
         x₁ ≥ 40
         x₂ ≥ 20
```
and the second-stage model given by:
```math
  maximize q₁(ξ)y₁ + q₂(ξ)y₂
    s.t  6y₁ + 10y₂ ≤ 60x₁
         8y₁ + 5y₂ ≤ 60x₂
         0 ≤ y₁ ≤ d₁(ξ)
         0 ≤ y₂ ≤ d₂(ξ)
```
where ``q₁(ξ), q₂(ξ), d₁(ξ), d₂(ξ)`` depend on the scenario ``ξ`` and ``x₁, x₂`` are first stage variables. Two scenarios are added so that two second stage models are generated.

```jldoctest
ξ₁ = @scenario q₁ = 24.0 q₂ = 28.0 d₁ = 500.0 d₂ = 100.0 probability = 0.4
ξ₂ = @scenario q₁ = 28.0 q₂ = 32.0 d₁ = 300.0 d₂ = 300.0 probability = 0.6

sp = StochasticProgram([ξ₁, ξ₂])

@stage 1 sp = begin
    @decision(sp, x₁ >= 40)
    @decision(sp, x₂ >= 20)
    @objective(sp, Min, 100*x₁ + 150*x₂)
    @constraint(sp, x₁ + x₂ <= 120)
end

@stage 2 sp = begin
    @uncertain q₁ q₂ d₁ d₂
    @variable(sp, 0 <= y₁ <= d₁)
    @variable(sp, 0 <= y₂ <= d₂)
    @objective(sp, Max, q₁*y₁ + q₂*y₂)
    @constraint(sp, 6*y₁ + 10*y₂ <= 60*x₁)
    @constraint(sp, 8*y₁ + 5*y₂ <= 80*x₂)
end

# output

Stochastic program with:
 * 2 decision variables
 * 2 scenarios of type Scenario
Solver is default solver

```

See also: [`@parameters`](@ref), [`@decision`](@ref), [`@uncertain`](@ref)
"""
macro stage(stage, args)
    @capture(args, sp_Symbol = def_) || error("Invalid syntax. Expected @stage stage sp = begin ... end")
    model_name = sp
    _error(x, str...) = begin
        macroname = Symbol(String(x.args[1])[2:end])
        JuMP._macro_error(macroname, prettify.(x.args[3:end]), x.args[2], str...)
    end
    # Flags for error checking
    seen_decision = :(false)
    seen_recourse = :(false)
    # Decision definitions might require parameter calculations,
    # so we first need to extract and save any such lines
    vardefs = Expr(:block)
    lastline = __source__
    decisiondefs = postwalk(def) do x
        if x isa LineNumberNode
            lastline = LineNumberNode(x.line, x.file)
        end
        if  @capture(x, @variable(m_Symbol, variabledef__)) ||
            @capture(x, @known(m_Symbol, variabledef__)) ||
            @capture(x, @constraint(m_Symbol, constdef__)) ||
            @capture(x, @expression(m_Symbol, expressiondef__)) ||
            @capture(x, @objective(m_Symbol, objdef__))
            # Check model name
            if m != model_name
                _error(x, "Inconsistent model name \"$m\", should be \"$model_name\".")
            end
            # Skip any line related to the JuMP model
            return Expr(:block)
        elseif @capture(x, @parameters args__) ||
               @capture(x, @uncertain args__)
            # Skip any line related to stochastics or unhandled @known/@parameter lines
            return Expr(:block)
        elseif @capture(x, @decision m_Symbol args__) || @capture(x, @recourse m_Symbol args__)
            # Check model name
            if m != model_name
                _error(x, "Inconsistent model name \"$m\", should be \"$model_name\".")
            end
            # Handle @decision
            return @q begin
                StochasticPrograms.@_decision known $stage $m $((args)...)
            end
        else
            # Anything else could be required for decision variable construction, and is therefore saved
            return x
        end
    end
    # Next, handle @decision annotations in main definition
    def = postwalk(def) do x
        if @capture(x, @decision args__)
            # Bookkeep for error checking
            seen_decision = :(true)
            return @q begin
                StochasticPrograms.@_decision decision $stage $((args)...)
            end
        end
        if @capture(x, @recourse args__)
            # Bookkeep for error checking
            seen_recourse = :(true)
            return @q begin
                StochasticPrograms.@_decision recourse $stage $((args)...)
            end
        end
        return x
    end
    # Handle parameters
    def = postwalk(def) do x
        if @capture(x, @parameters arg_)
            code = Expr(:block)
            for paramdef in block(prettify(arg)).args
                if @capture(paramdef, key_Symbol = val_) || @capture(paramdef, key_Symbol)
                    push!(code.args, :($key = stage.$key))
                else
                    _error(x, "Incorrect @parameters syntax. Specify parameter names, possibly with a default value.")
                end
            end
            # Extracted parameters might be required for decision variable construction
            pushfirst!(decisiondefs.args, code)
            return code
        elseif @capture(x, @parameters args__)
            code = Expr(:block)
            for paramdef in args
                if @capture(paramdef, key_Symbol = val_) || @capture(paramdef, key_Symbol)
                    push!(code.args, :($key = stage.$key))
                else
                    _error(x, "Incorrect @parameters syntax. Specify parameter names, possibly with a default value.")
                end
            end
            # Extracted parameters might be required for decision variable construction
            pushfirst!(decisiondefs.args, code)
            return code
         elseif @capture(x, @uncertain var_Symbol::t_Symbol)
            stage == 1 && _error(x, "@uncertain declarations cannot be used in the first stage.")
            return :($var::$t = scenario)
        elseif @capture(x, @uncertain vars__ from scenvar_Symbol::t_Symbol)
            stage == 1 && _error(x, "@uncertain declarations cannot be used in the first stage.")
            code = @q begin
                $scenvar::$t = scenario
            end
            for var in vars
                varkey = Meta.quot(var)
                push!(code.args, :($var = getproperty($scenvar, $varkey)))
            end
            return code
        elseif @capture(x, @uncertain vars__ from t_Symbol)
            stage == 1 && _error(x, "@uncertain declarations cannot be used in the first stage.")
            code = @q begin
                scenvar::$t = scenario
            end
            for var in vars
                varkey = Meta.quot(var)
                push!(code.args, :($var = getproperty(scenvar, $varkey)))
            end
            return code
        elseif @capture(x, @uncertain var_Symbol::t_Symbol = scenariodef_)
            stage == 1 && _error(x, "@uncertain declarations cannot be used in the first stage.")
            return @q begin
                $var::$t = scenario
            end
        elseif @capture(x, @uncertain vars__ from scenvar_Symbol::t_Symbol = scenariodef_)
            stage == 1 && _error(x, "@uncertain declarations cannot be used in the first stage.")
            code = @q begin
                $scenvar::$t = scenario
            end
            for var in vars
                varkey = Meta.quot(var)
                push!(code.args, :($var = getproperty($scenvar, $varkey)))
            end
            return code
        elseif @capture(x, @uncertain vars__ from t_Symbol = scenariodef_)
            stage == 1 && _error(x, "@uncertain declarations cannot be used in the first stage.")
            code = @q begin
                scenvar::$t = scenario
            end
            for var in vars
                varkey = Meta.quot(var)
                push!(code.args, :($var = getproperty(scenvar, $varkey)))
            end
            return code
        elseif @capture(x, @uncertain args_) && typeof(args) == Expr && args.head == :ref
            stage == 1 && _error(x, "@uncertain declarations cannot be used in the first stage.")
            scenvar = first(args.args)
            reference = :(Containers.@container $args "uncertain value")
            code = @q begin
                typeof(scenario) <: Scenario{D} where D <: Union{Array, StochasticPrograms.DenseAxisArray} || error("@uncertain declarations of type `@uncertain ξ[i = ..., j = ..., ...]` only support scenarios of type `Scenario` with Array or DenseAxisArray as underlying data. Consider declaring a custom scenario type.")
                size(scenario.data) == size($reference) || error("Given scenario \n\n$scenario \n\ndoes not match @uncertain declaration \n\n$($reference).")
                $scenvar = scenario.data
            end
            return code
        elseif @capture(x, @uncertain args_) && typeof(args) == Expr && args.head == :typed_vcat
            stage == 1 && _error(x, "@uncertain declarations cannot be used in the first stage.")
            scenvar = first(args.args)
            reference = :(Containers.@container $args "uncertain value")
            code = @q begin
                typeof(scenario) <: Scenario{D} where D <: StochasticPrograms.SparseAxisArray || error("@uncertain declarations of type `@uncertain ξ[i = ..., j = ..., ...; ...]` only support scenarios of type `Scenario` with SparseAxisArray as underlying data. Consider declaring a custom scenario type.")
                keys(scenario.data.data) == keys($reference.data) || error("Given scenario \n\n$scenario \n\ndoes not match @uncertain declaration \n\n$($reference).")
                $scenvar = scenario.data
            end
            return code
        elseif @capture(x, @uncertain args__)
            stage == 1 && _error(x, "@uncertain declarations cannot be used in the first stage.")
            code = @q begin
                typeof(scenario) <: Scenario || error("@uncertain declarations of type `@uncertain var1, var2, ...` only support scenarios of type `Scenario`. Consider declaring a custom scenario type.")
            end
            for var in args
                varkey = Meta.quot(var)
                code = @q begin
                    $code
                    $var = try
                        $var = scenario.data[$varkey]
                    catch err
                        error("Given scenario $scenario does not match @uncertain declaration.")
                    end
                end
            end
            return code
        else
            return x
        end
    end
    # The first stage is treated different from the subsequent stages
    generatordefs = if stage == 1
        @q begin
            $(esc(sp)).generator[:stage_1] = ($(esc(model_name))::JuMP.Model, $(esc(:stage))) -> begin
                $(esc(def))
                # Cache sense and objective function
                sense = objective_sense($(esc(model_name)))
                obj = moi_function(objective_function($(esc(model_name))))
                add_stage_objective!($(esc(model_name)), 1, sense, obj)
	            return $(esc(model_name))
            end
        end
    else
        @q begin
            $(esc(sp)).generator[Symbol(:stage_,$stage)] = ($(esc(model_name))::JuMP.Model, $(esc(:stage)), $(esc(:scenario))::AbstractScenario) -> begin
                $(esc(def))
                # Cache sense and objective function
                sense = objective_sense($(esc(model_name)))
                obj = moi_function(objective_function($(esc(model_name))))
                add_stage_objective!($(esc(model_name)), $stage, sense, obj)
	            return $(esc(model_name))
            end
        end
    end
    # Create definition code
    code = @q begin
        isa($(esc(sp)), StochasticProgram) || error("Given object is not a stochastic program.")
        n = num_stages($(esc(sp)))
        $stage > n && error("Cannot specify stage $($stage) for stochastic program with $n stages.")
        $stage == n && $seen_decision && error("@decision declarations cannot be used in the final stage. Consider @recourse instead.")
        if $stage < n
            $seen_recourse && error("@recourse declarations can only be used in the final stage.")
            $(esc(sp)).generator[Symbol(:stage_,$stage,:_decisions)] = ($(esc(model_name))::JuMP.Model, $(esc(:stage))) -> begin
                $(esc(decisiondefs))
	            return $(esc(model_name))
            end
        end
        # Stage model generation code
        $generatordefs
        # Return stochastic program
        $(esc(sp))
    end
    # Return code
    return code
end
"""
    @first_stage(def)

Add a first stage model generation recipe to `stochasticprogram` using the syntax
```julia
@first_stage stochasticprogram::StochasticProgram = begin
    ...
end [defer]
```
where JuMP syntax is used inside the block to define the first stage model. During definition, the first stage model is referenced through the reserved keyword `model`.

## Examples

The following defines the first stage model given by:

```math
  minimize 100x₁ + 150x₂
    s.t  x₁ + x₂ ≤ 120
         x₁ ≥ 40
         x₂ ≥ 20
```

```julia
@first_stage sp = begin
    @decision(model, x₁ >= 40)
    @decision(model, x₂ >= 20)
    @objective(model, Min, 100*x₁ + 150*x₂)
    @constraint(model, x₁ + x₂ <= 120)
end
```

See also: [`@second_stage`](@ref)
"""
macro first_stage(arg)
    @capture(arg, sp_Symbol = def_) || error("Invalid syntax. Expected @first_stage sp = begin ... end")
    return esc(:(@stage 1 $arg))
end
"""
    @second_stage(def)

Add a second stage model generation recipe to `stochasticprogram` using the syntax
```julia
@second_stage stochasticprogram::StochasticProgram = begin
    @known var1 var2 ...
    ...
end
```
where JuMP syntax is used inside the block to define the second stage model. During definition, the second stage model is referenced through the reserved keyword `model`.

## Examples

The following defines the second stage model given by:
```math
  minimize q₁(ξ)y₁ + q₂(ξ)y₂
    s.t  6y₁ + 10y₂ ≤ 60x₁
         8y₁ + 5y₂ ≤ 60x₂
         0 ≤ y₁ ≤ d₁(ξ)
         0 ≤ y₂ ≤ d₂(ξ)
```
where ``q₁(ξ), q₂(ξ), d₁(ξ), d₂(ξ)`` depend on the scenario ``ξ`` and ``x₁, x₂`` are first stage variables. Two scenarios are added so that two second stage models are generated.

```julia
@second_stage sp = begin
    @known x₁ x₂
    @uncertain q₁ q₂ d₁ d₂
    @variable(model, 0 <= y₁ <= d₁)
    @variable(model, 0 <= y₂ <= d₂)
    @objective(model, Min, q₁*y₁ + q₂*y₂)
    @constraint(model, 6*y₁ + 10*y₂ <= 60*x₁)
    @constraint(model, 8*y₁ + 5*y₂ <= 80*x₂)
end
```

See also: [`@first_stage`](@ref)
"""
macro second_stage(arg)
    @capture(arg, sp_Symbol = def_) || error("Invalid syntax. Expected @second_stage sp = begin ... end")
    return esc(@q begin
        @stage 2 $arg
        generate!($sp)
    end)
end
"""
    @parameters(def)

Define the problem parameters in a @stage block
```julia
@parameters param1, param2, ...
```
possibly with default values. Any defined parameter without a default value must be supplied as a keyword argument to [`instantiate`](@ref) when creating models.

## Examples

```julia
@parameters d

@parameters begin
    Crops = [:wheat, :corn, :beets]
    Cost = Dict(:wheat=>150, :corn=>230, :beets=>260)
    Budget = 500
end
```

See also [`@decision`](@ref), [`@uncertain`](@ref), [`@stage`](@ref)
"""
macro parameters(def) @warn "@parameters should be used inside a @stage block." end
