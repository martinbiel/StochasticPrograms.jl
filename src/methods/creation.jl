# Creation macros #
# ========================== #
"""
    @define_scenario(def)

Define a scenario type compatible with StochasticPrograms using the syntax
```julia
@define_scenario name = begin
    ...structdef...

    [@zero begin
        ...
        return zero(scenario)
    end]

    [@expectation begin
        ...
        return expected(scenarios)
     end]
end
```
The generated type is referenced through `name` and a default constructor is always generated. This constructor accepts the keyword `probability` to set the probability of the scenario occuring. Otherwise, any internal variables and specialized constructors are defined in the @define_scenario block as they would be in any Julia struct.

If possible, a `zero` method and an `expected` method will be generated for the defined type. Otherwise, or if the default implementation is not desired, these can be user provided through [`@zero`](@ref) and [`@expectation`](@ref).

The defined scenario type will be available on all Julia processes.

## Examples

The following defines a simple scenario ``ξ`` with a single value.

```jldoctest
@define_scenario ExampleScenario = begin
    ξ::Float64
end

ExampleScenario(1.0, probability = 0.5)

# output

ExampleScenario with probability 0.5
  ξ: 1.0

```

See also: [`@zero`](@ref), [`@expectation`](@ref), [`@sampler`](@ref)
"""
macro define_scenario(arg)
    @capture(arg, scenarioname_Symbol = scenariodef_) || error("Invalid syntax. Expected: scenarioname = begin scenariodef end")
    vars = Vector{Symbol}()
    vartypes = Vector{Union{Expr,Symbol}}()
    vardefs = Vector{Expr}()
    zerodefs = Vector{Expr}()
    expectdefs = Vector{Expr}()
    def = postwalk(prettify(scenariodef)) do x
        if @capture(x, var_Symbol::vartype_)
            push!(vars, var)
            push!(vartypes, vartype)
            push!(vardefs, x)
            return x
        end
        if @capture(x, @zero zerodef_)
            push!(zerodefs, zerodef)
            return @q begin end
        end
        if @capture(x, @expectation expectdef_)
            push!(expectdefs, expectdef)
            return @q begin end
        end
        return x
    end
    # Handle zero definition
    if length(zerodefs) > 1
        error("Only provide one zero implementation")
    end
    provided_zerodef, zerodef = if length(zerodefs) == 1
        zerodef = zerodefs[1]
        true, zerodef
    else
        false, Expr(:block)
    end
    # Handle expectation definition
    if length(expectdefs) > 1
        error("Only provide one expectation implementation")
    end
    provided_expectdef, expectdef = if length(expectdefs) == 1
        expectdef = expectdefs[1]
        expectdef = postwalk(prettify(expectdef)) do x
            @capture(x, constructor_Symbol(args__)) && constructor == scenarioname && return :(StochasticPrograms.ExpectedScenario($x))
            return x
        end
        true, expectdef
    else
        false, Expr(:block)
    end
    # Prepare automatic expectation definition
    combine = Expr(:call)
    push!(combine.args, scenarioname)
    push!(combine.args, :($(Expr(:parameters, :(probability = 1.0)))))
    for var in vars
        push!(combine.args, :(probability(s1)*s1.$var + probability(s2)*s2.$var))
    end
    # Prepare automatic scenariotext definition
    textdef = Expr(:block)
    for var in vars
        key = Meta.quot(var)
        push!(textdef.args, :(print(io, "\n  $($key): $(scenario.$var)")))
    end
    # Define scenario type
    code = @q begin
        if StochasticPrograms.supports_expected([$(vartypes...)], $provided_expectdef) || $provided_expectdef
            if StochasticPrograms.supports_zero([$(vartypes...)], $provided_zerodef) || $provided_zerodef
                struct $scenarioname <: AbstractScenario
                    probability::Probability
                    $def
                    function (::Type{$scenarioname})($(vardefs...); probability::AbstractFloat = 1.0)
                        return new(Probability(probability), $(vars...))
                    end
                end
                if $provided_zerodef
                    function Base.zero(::Type{$scenarioname})
                        $zerodef
                    end
                else
                    function Base.zero(::Type{$scenarioname})
                        return $scenarioname(zero.([$(vartypes...)])...; probability = 1.0)
                    end
                end
                if $provided_expectdef
                    function StochasticPrograms.expected(scenarios::Vector{$scenarioname})
                        isempty(scenarios) && return StochasticPrograms.ExpectedScenario(zero($scenarioname))
                        $expectdef
                    end
                else
                    function StochasticPrograms.expected(scenarios::Vector{$scenarioname})
                        isempty(scenarios) && return StochasticPrograms.ExpectedScenario(zero($scenarioname))
                        return StochasticPrograms.ExpectedScenario(reduce(scenarios) do s1, s2
                                                                   $combine
                                                                   end)
                    end
                end
                function StochasticPrograms.scenariotext(io::IO, scenario::$scenarioname)
                    $textdef
                    return io
                end
            else
                @warn "The scenario type $(string($(Meta.quot(scenarioname)))) was not defined. A user-provided implementation \n\n    function zero(::Type{{$(string($(Meta.quot(scenarioname))))})\n        ...\n    end\n\nis required."
            end
        else
            @warn "The scenario type $(string($(Meta.quot(scenarioname)))) was not defined. A user-provided implementation \n\n    function expected(scenarios::Vector{$(string($(Meta.quot(scenarioname))))})\n        ...\n    end\n\nis required."
        end
    end
    code = prettify(code)
    code = @q begin
        if (@__MODULE__) == $(esc(:Main))
            @everywhere begin
                $code
            end
        else
            $(esc(code))
        end
    end
    return prettify(code)
end
"""
    @zero(def)

Define the additive zero scenario inside a @scenario block using the syntax:
```julia
@zero begin
    ...
    return zero_scenario
end
```

## Examples

The following defines a zero scenario for the example scenario defined in [`@define_scenario`](@ref)

```julia
@zero begin
    return ExampleScenario(0.0)
end
```

See also [`@define_scenario`](@ref)
"""
macro zero(def) @warn "@zero should be used inside a @define_scenario block." end
"""
    @expectation(def)

Define how to form the expected scenario inside a [`@define_scenario`](@ref) block. The scenario collection is accessed through the reserved keyword `scenarios`.

```julia
@zero begin
    ...
    return zero_scenario
end
```

## Examples

The following defines expectation for the example scenario defined in [`@scenario`](@ref)

```julia
@expectation begin
    return ExampleScenario(sum([probability(s)*s.ξ for s in scenarios]))
end
```

See also [`@define_scenario`](@ref)
"""
macro expectation(def) @warn "@expectation should be used inside a @scenario block." end
"""
    @scenario(args..., probability = )

Create [`Scenario`](@ref) matching some [`@uncertain`](@ref) declaration with a supplied probability.


    @scenario(var1 = val1, var2 = val2, ..., probability = 1.0)

Create [`Scenario`](@ref) matching [`@uncertain`](@ref) annotation of the form `@uncertain var1, var2, ...`


    @scenario(ξ[i=..., j=..., ...] = values, probability = 1.0)

Create [`Scenario`](@ref) matching [`@uncertain`](@ref) annotation of the form `@uncertain ξ[i=..., j=..., ...]`. `values` must have the same dimension as the specified index sets.


    @scenario(ξ[i=..., j=..., ...], expr, probability = 1.0, requested_container = :Auto)

Create [`Scenario`](@ref) matching [`@uncertain`](@ref) annotation of the form `@uncertain ξ[i=..., j=..., ...]`. Wraps JuMP's `@container` macro to create `DenseAxisArray` or `SparseAxisArray` as underlying data. See `@container` for further syntax information.

## Examples

The following are equivalent ways of creating an instance of the random vector ``[q₁(ξ) q₂(ξ) d₁(ξ) d₂(ξ)]``  of probability ``0.4`` and values ``[24.0 28.0 500.0 100.0]``.

```julia
@scenario q₁ = 24.0 q₂ = 28.0 d₁ = 500.0 d₂ = 100.0 probability = 0.4

@scenario ξ[i in 1:4] = [24.0, 28.0, 500.0, 100.0] probability = 0.4
```

"""
macro scenario(args...)
    args, kw_args, probability, requested_container = _extract_kw_args(args)
    if length(args) == 0
        if length(kw_args) > 1 || @capture(kw_args[1], var_Symbol = val_)
            return :(Scenario(; $(esc.(kw_args)...), probability = $(esc(probability))))
        else
            if @capture(kw_args[1], idx_ = val_)
                idxvars, indices = Containers._build_ref_sets(error, idx)
                values = @q begin
                    if $indices isa VectorizedProductIterator && all(idx -> idx isa Base.OneTo, $indices.prod.iterators)
                        $(esc(val))[$(esc.(idxvars)...)]
                    else
                        if $(esc(val)) isa Dict
                            $(esc(val))[($(esc.(idxvars)...),)]
                        elseif $(esc(val)) isa Array
                            zero(eltype($(esc(val))))
                        else
                            error("Unsupported right hand side in @scenario assignment.")
                        end
                    end
                end
                code = Containers.container_code(idxvars, indices, :($values), requested_container)
                return @q begin
                    ξ = Scenario($code; probability = $(esc(probability)))
                    if ξ.data isa Array
                        size(ξ.data) == size($val) || error("Dimensions of right hand side in @scenario assignment differ from left hand side.")
                    elseif ξ.data isa DenseAxisArray
                        ξ.data.data .= $val
                    elseif ξ.data isa SparseAxisArray
                        length(ξ.data.data) == length($val) || error("Dimensions of right hand side in @scenario assignment differ from left hand side.")
                    end
                    ξ
                end
            end
        end
    end
    @assert length(args) == 2
    @assert isempty(kw_args)
    idx, values = args
    code = Containers.parse_container(error, idx, esc(values), requested_container)
    return :(Scenario($code; probability = $(esc(probability))))
end
function _extract_kw_args(args)
    kw_args = filter(x -> isexpr(x, :(=)) && x.args[1] != :container && x.args[1] != :probability, collect(args))
    flat_args = filter(x->!isexpr(x, :(=)), collect(args))
    requested_container = :Auto
    probability = 1.0
    for kw in args
        if isexpr(kw, :(=)) && kw.args[1] == :container
            requested_container = kw.args[2]
        end
        if isexpr(kw, :(=)) && kw.args[1] == :probability
            probability = kw.args[2]
        end
    end
    return flat_args, kw_args, probability, requested_container
end
"""
    @sampler(def)

Define a sampler type for some `scenariotype` compatible with StochasticPrograms using the syntax
```julia
@sampler samplername = begin
    ...internals...

    @sample scenariotype begin
        ...
        return scenario
    end
end
```
Any internal state required by the sampler, as well as any specialized constructor, are defined in the @sampler block as they would be in any Julia struct. Define the sample operation inside the [`@sample`](@ref) block and specify the `scenariotype` that the sampler returns. The defined sampler will be available on all Julia processes.

## Examples

The following defines a simple dummy sampler, with some internal weight value, for the scenario defined in [`@scenario`](@ref), and samples one scenario.

```jldoctest; setup = :(@scenario ExampleScenario = ξ::Float64), filter = r".*"
@sampler ExampleSampler = begin
    w::Float64

    ExampleSampler(w::AbstractFloat) = new(w)

    @sample ExampleScenario begin
        @parameters w
        return ExampleScenario(w*randn(), probability = rand())
    end
end
s = ExampleSampler(2.0)
s()

# output

ExampleScenario with probability 0.29
  ξ: 1.48


```

See also: [`@sample`](@ref), [`@scenario`](@ref)
"""
macro sampler(arg)
    @capture(prettify(arg), samplername_Symbol = samplerdef_) || error("Invalid syntax. Expected: sampler = begin samplerdef end")
    scenarioname = :undefined
    sampledefs = Vector{Expr}()
    def = postwalk(prettify(samplerdef)) do x
        if @capture(x, @parameters args__)
            code = Expr(:block)
            for param in args
                push!(code.args, :($param = sampler.$param))
            end
            return code
        elseif @capture(x, @sample sname_ sampledef_)
            scenarioname = sname
            push!(sampledefs, sampledef)
            return @q begin end
        else
            return x
        end
    end
    # Handle sample definition
    length(sampledefs) == 1 || error("Must provide exactly one @sample operation.")
    sampledef = sampledefs[1]
    # Define sampler type
    code = @q begin
        struct $samplername <: AbstractSampler{$scenarioname}
            $def
        end
        function (sampler::$samplername)()
            $sampledef
        end
    end
    code = prettify(code)
    code = @q begin
        if (@__MODULE__) == $(esc(:Main))
            @everywhere begin
                $code
            end
        else
            $(esc(code))
        end
    end
    return prettify(code)
end
"""
    @sample(def)

Define the sample operaton inside a @sampler block, using the syntax
```julia
@sample begin
    ...
    return sampled_scenario
end
```
The sampler object is referenced through the reserved keyword `sampler`, from which any internals can be accessed.
"""
macro sample(def) @warn "@sample should be used inside a @sampler block." end
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
    @capture(arg, sp_Symbol = def_) || error("Invalid syntax. Expected stage, multistage = begin JuMPdef end")
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
    return esc(:(@stage 2 $arg))
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
"""
    @decision(model, expr, args..., kw_args...)

Add a decision variable to `model` described by the expression `expr`. If used inside a [`@stage`](@ref) block, the created variable can be used in subsequent stage blocks. See `@variable` for syntax details.

## Examples

```julia
@decision(model, x >= 40)
```

See also [`@parameters`](@ref), [`@uncertain`](@ref), [`@stage`](@ref)
"""
macro decision(def...) @warn "@decision should be used inside a @stage block." end
macro _decision(args...)
    args = [args...]
    # Check context of decision definition
    known = if args[1] isa Symbol && args[1] == :known
        known = true
    else
        args[1] == :unknown || error("Incorrect usage of @_decision.")
        known = false
    end
    # Remove context from args
    deleteat!(args, 1)
    # Move any set definitions
    set = NoSpecifiedConstraint()
    for (i, arg) in enumerate(args)
        set, arg, found = extract_set(arg)
        if found
            if arg == :()
                deleteat!(args, i)
            else
                args[i] = arg
            end
            break
        end
    end
    # Return expression based on context
    if known
        return esc(:(@variable $((args)...) set = StochasticPrograms.KnownSet()))
    else
        return esc(:(@variable $((args)...) set = StochasticPrograms.DecisionSet(constraint = $set)))
    end
end

"""
    @known(def)

Annotate each decision taken in the previous stage. Any [`@decision`](@ref) included in a [`@stochastic_model`](@ref) definition will implicitly add `@known` annotations to subsequent stages.

## Examples

```julia
@known x₁, x₂
```

See also [`@decision`](@ref), [`@parameters`](@ref), [`@uncertain`](@ref), [`@stage`](@ref)
"""
macro known(args...)
    code = Expr(:block)
    for var in args
        varkey = Meta.quot(var)
        push!(code.args, :($(esc(var)) = $(esc(:model))[$varkey]))
    end
    return code
end
"""
    @uncertain(def)

In a @stage block, annotate each uncertain variable using the syntax
```julia
@uncertain var1, var2, ...
```
or using JuMP's container syntax
```julia
@uncertain ξ[i=..., j=..., ...]
```
This assumes that the [`Scenario`] type is used. Matching scenario data is then conveniently created using [`@scenario`](@ref).

Alternatively, user-defined scenarios can be specified by annotating the type. Also, inside a @stochastic_model block, user-defined scenarios can be created during the @uncertain annotation, using [`@define_scenario`](@ref) syntax.

## Examples

The following are equivalent ways of declaring a random vector ``[q₁(ξ) q₂(ξ) d₁(ξ) d₂(ξ)]`` in a `@stage` block, and creating a matching scenario instance of probability ``0.4`` and values ``[24.0 28.0 500.0 100.0]``.ö

```julia
@uncertain q₁ q₂ d₁ d₂
ξ₁ = @scenario q₁ = 24.0 q₂ = 28.0 d₁ = 500.0 d₂ = 100.0 probability = 0.4

@uncertain ξ[i in 1:4]
ξ₁ = @scenario ξ[i in 1:4] = [24.0, 28.0, 500.0, 100.0] probability = 0.4

@define_scenario SimpleScenario = begin
    q₁::Float64
    q₂::Float64
    d₁::Float64
    d₂::Float64
end
@uncertain ξ::SimpleScenario
ξ₁ = SimpleScenario(24.0, 28.0, 500.0, 100.0, probability = 0.4)

@stochastic_model begin
    ...
    @uncertain ξ::SimpleScenario = begin
        q₁::Float64
        q₂::Float64
        d₁::Float64
        d₂::Float64
    end
    ...
end
ξ₁ = SimpleScenario(24.0, 28.0, 500.0, 100.0 probability = 0.4)
```

See also [`@scenario`](@ref), [`@define_scenario`](@ref), [`@parameters`](@ref), [`@decision`](@ref), [`@stage`](@ref)
"""
macro uncertain(def) @warn "@uncertain should be used inside a @stage block." end
"""
    @stage(def)

Add a stage model generation recipe to `stochasticprogram` using the syntax
```julia
@stage stage stochasticprogram::StochasticProgram = begin
    @parameters param1 param2 ...
    @decision(model, var) ...
    @uncertain ξ
    ... JuMPdef ...
    ...
end
```
where JuMP syntax is used inside the block to define the stage model. During definition, the second stage model is referenced through the reserved keyword `model`.

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
    @decision(model, x₁ >= 40)
    @decision(model, x₂ >= 20)
    @objective(model, Min, 100*x₁ + 150*x₂)
    @constraint(model, x₁ + x₂ <= 120)
end

@stage 2 sp = begin
    @uncertain q₁ q₂ d₁ d₂
    @variable(model, 0 <= y₁ <= d₁)
    @variable(model, 0 <= y₂ <= d₂)
    @objective(model, Max, q₁*y₁ + q₂*y₂)
    @constraint(model, 6*y₁ + 10*y₂ <= 60*x₁)
    @constraint(model, 8*y₁ + 5*y₂ <= 80*x₂)
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
    @capture(args, sp_Symbol = def_) || error("Invalid syntax. Expected stage, multistage = begin JuMPdef end")
    # Decision definitions might require parameter calculations,
    # so we first need to extract and save any such lines
    vardefs = Expr(:block)
    decisiondefs = postwalk(def) do x
        if  @capture(x, @variable(m_Symbol, variabledef__)) ||
            @capture(x, @known(m_Symbol, variabledef__)) ||
            @capture(x, @constraint(m_Symbol, constdef__)) ||
            @capture(x, @expression(m_Symbol, expressiondef__)) ||
            @capture(x, @objective(m_Symbol, objdef__)) ||
            @capture(x, @parameters args__) ||
            @capture(x, @uncertain args__)
            # Skip any line related to the JuMP model, stochastics, or unhandled @parameter lines
            return Expr(:block)
        elseif @capture(x, @decision args__)
            # Handle @decision
            return @q begin
                StochasticPrograms.@_decision known $((args)...)
            end
        else
            # Anything else could be required for decision variable construction, and is therefore saved
            return x
        end
    end
    # Next, handle @decision annotations in main definition
    def = postwalk(def) do x
        if @capture(x, @decision args__)
            return @q begin
                StochasticPrograms.@_decision unknown $((args)...)
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
                    error("Incorrect @parameters syntax. Specify parameter names, possibly with a default value.")
                end
            end
            # Extracted parameters might be required for decision variable construction
            pushfirst!(decisiondefs.args, code)
            return code
        elseif @capture(x, @parameters args__)
            code = Expr(:block)
            for param in args
                push!(code.args, :($param = stage.$param))
            end
            # Extracted paremeters might be required for decision variable construction
            pushfirst!(decisiondefs.args, code)
            return code
         elseif @capture(x, @uncertain var_Symbol::t_Symbol)
            stage == 1 && error("@uncertain declarations cannot be used in the first stage.")
            return :($var::$t = scenario)
        elseif @capture(x, @uncertain vars__ from scenvar_Symbol::t_Symbol)
            stage == 1 && error("@uncertain declarations cannot be used in the first stage.")
            code = @q begin
                $scenvar::$t = scenario
            end
            for var in vars
                varkey = Meta.quot(var)
                push!(code.args, :($var = getproperty($scenvar, $varkey)))
            end
            return code
        elseif @capture(x, @uncertain vars__ from t_Symbol)
            stage == 1 && error("@uncertain declarations cannot be used in the first stage.")
            code = @q begin
                scenvar::$t = scenario
            end
            for var in vars
                varkey = Meta.quot(var)
                push!(code.args, :($var = getproperty(scenvar, $varkey)))
            end
            return code
        elseif @capture(x, @uncertain var_Symbol::t_Symbol = scenariodef_)
            stage == 1 && error("@uncertain declarations cannot be used in the first stage.")
            return @q begin
                $var::$t = scenario
            end
        elseif @capture(x, @uncertain vars__ from scenvar_Symbol::t_Symbol = scenariodef_)
            stage == 1 && error("@uncertain declarations cannot be used in the first stage.")
            code = @q begin
                $scenvar::$t = scenario
            end
            for var in vars
                varkey = Meta.quot(var)
                push!(code.args, :($var = getproperty($scenvar, $varkey)))
            end
            return code
        elseif @capture(x, @uncertain vars__ from t_Symbol = scenariodef_)
            stage == 1 && error("@uncertain declarations cannot be used in the first stage.")
            code = @q begin
                scenvar::$t = scenario
            end
            for var in vars
                varkey = Meta.quot(var)
                push!(code.args, :($var = getproperty(scenvar, $varkey)))
            end
            return code
        elseif @capture(x, @uncertain args_) && typeof(args) == Expr && args.head == :ref
            stage == 1 && error("@uncertain declarations cannot be used in the first stage.")
            scenvar = first(args.args)
            reference = :(Containers.@container $args "uncertain value")
            code = @q begin
                typeof(scenario) <: Scenario{D} where D <: Union{Array, StochasticPrograms.DenseAxisArray} || error("@uncertain declarations of type `@uncertain ξ[i = ..., j = ..., ...]` only support scenarios of type `Scenario` with Array or DenseAxisArray as underlying data. Consider declaring a custom scenario type.")
                size(scenario.data) == size($reference) || error("Given scenario \n\n$scenario \n\ndoes not match @uncertain declaration \n\n$($reference).")
                $scenvar = scenario.data
            end
            return code
        elseif @capture(x, @uncertain args_) && typeof(args) == Expr && args.head == :typed_vcat
            stage == 1 && error("@uncertain declarations cannot be used in the first stage.")
            scenvar = first(args.args)
            reference = :(Containers.@container $args "uncertain value")
            code = @q begin
                typeof(scenario) <: Scenario{D} where D <: StochasticPrograms.SparseAxisArray || error("@uncertain declarations of type `@uncertain ξ[i = ..., j = ..., ...; ...]` only support scenarios of type `Scenario` with SparseAxisArray as underlying data. Consider declaring a custom scenario type.")
                keys(scenario.data.data) == keys($reference.data) || error("Given scenario \n\n$scenario \n\ndoes not match @uncertain declaration \n\n$($reference).")
                $scenvar = scenario.data
            end
            return code
        elseif @capture(x, @uncertain args__)
            stage == 1 && error("@uncertain declarations cannot be used in the first stage.")
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
            $(esc(sp)).generator[:stage_1] = ($(esc(:model))::JuMP.Model, $(esc(:stage))) -> begin
                $(esc(def))
	            return $(esc(:model))
            end
        end
    else
        @q begin
            $(esc(sp)).generator[Symbol(:stage_,$stage)] = ($(esc(:model))::JuMP.Model, $(esc(:stage)), $(esc(:scenario))::AbstractScenario) -> begin
                $(esc(def))
	            return $(esc(:model))
            end
        end
    end
    # Create definition code
    code = @q begin
        isa($(esc(sp)), StochasticProgram) || error("Given object is not a stochastic program.")
        $(esc(sp)).generator[Symbol(:stage_,$stage,:_decisions)] = ($(esc(:model))::JuMP.Model, $(esc(:stage))) -> begin
            $(esc(decisiondefs))
	        return $(esc(:model))
        end
        # Stage model generation code
        $generatordefs
        $(esc(sp))
    end
    # Return code
    return code
end
# ========================== #
