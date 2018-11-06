# Creation macros #
# ========================== #
"""
    @scenario(def)

Define a scenario type compatible with StochasticPrograms using the syntax
```julia
@scenario name = begin
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
The generated type is referenced through [name]Scenario and a default constructor is always generated. This constructor accepts the keyword `probability` to set the probability of the scenario occuring. Otherwise, any internal variables and specialized constructors are defined in the @scenario block as they would be in any Julia struct.

If possible, a `zero` method and an `expected` method will be generated for the defined type. Otherwise, or if the default implementation is not desired, these can be user provided through [`@zero`](@ref) and [`@expectation`](@ref).

The defined scenario type will be available on all Julia processes.

## Examples

The following defines a simple scenario ``ξ`` with a single value.

```jldoctest
@scenario Example = begin
    ξ::Float64
end

ExampleScenario(1.0, probability = 0.5)

# output

ExampleScenario with probability 0.5

```

See also: [`@zero`](@ref), [`@expectation`](@ref), [`@sampler`](@ref)
"""
macro scenario(arg)
    @capture(arg, name_Symbol = scenariodef_) || error("Invalid syntax. Expected: scenarioname = begin scenariodef end")
    scenarioname = Symbol(name, :Scenario)
    vars = Vector{Symbol}()
    vartypes = Vector{Union{Expr,Symbol}}()
    vardefs = Vector{Expr}()
    zerodefs = Vector{Expr}()
    expectdefs = Vector{Expr}()
    def = postwalk(prettify(scenariodef)) do x
        @capture(x, constructor_Symbol) && constructor == name && return scenarioname
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
            else
                @warn "The scenario type $(string($(Meta.quot(name)))) was not defined. A user-provided implementation \n\n    function zero(::Type{{$(string($(Meta.quot(scenarioname))))})\n        ...\n    end\n\nis required."
            end
        else
            @warn "The scenario type $(string($(Meta.quot(name)))) was not defined. A user-provided implementation \n\n    function expected(scenarios::Vector{$(string($(Meta.quot(scenarioname))))})\n        ...\n    end\n\nis required."
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

The following defines a zero scenario for the example scenario defined in [`@scenario`](@ref)

```julia
@zero begin
    return ExampleScenario(0.0)
end
```

See also [`@scenario`](@ref)
"""
macro zero(def) @warn "@zero should be used inside a @scenario block." end
"""
    @expectation(def)

Define how to form the expected scenario inside a @scenario block. The scenario collection is accessed through the reserved keyword `scenarios`.

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

See also [`@scenario`](@ref)
"""
macro expectation(def) @warn "@expectation should be used inside a @scenario block." end
"""
    @sampler(def)

Define a sampler for some `scenario` type compatible with StochasticPrograms using the syntax
```julia
@sampler [samplername] scenario = begin
    ...internals...

    @sample begin
        ...
        return scenario
    end
end
```
Any internal state required by the sampler, as well as any specialized constructor, are defined in the @sampler block as they would be in any Julia struct. Define the sample operation inside the [`@sample`](@ref) block. Optionally, give a `samplername` to the sampler. Otherwise, it will be named [scenario]Sampler. The defined sampler will be available on all Julia processes.

## Examples

The following defines a simple dummy sampler, with some internal weight value, for the scenario defined in [`@scenario`](@ref), and samples one scenario.

```jldoctest; setup = :(@scenario Example = ξ::Float64), filter = r".*"
@sampler Example = begin
    w::Float64

    Example(w::AbstractFloat) = new(w)

    @sample begin
        w = sampler.w
        return ExampleScenario(w*randn(), probability = rand())
    end
end
s = ExampleSampler(2.0)
s()

# output

ExampleScenario(Probability(0.29), 1.48)

```

See also: [`@sample`](@ref), [`@scenario`](@ref)
"""
macro sampler(arg) esc(:(@sampler(nothing, $arg))) end
macro sampler(name, arg)
    @capture(prettify(arg), sname_Symbol = samplerdef_) || error("Invalid syntax. Expected: scenarioname = begin samplerdef end")
    scenarioname = Symbol(sname, :Scenario)
    samplername = name == :nothing ? Symbol(sname, :Sampler) : Symbol(name, :Sampler)
    sampledefs = Vector{Expr}()
    def = postwalk(prettify(samplerdef)) do x
        @capture(x, constructor_Symbol) && (constructor == sname || constructor == name) && return samplername
        @capture(x, @sample sampledef_) || return x
        push!(sampledefs, sampledef)
        return @q begin end
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

Define the sample operation inside a @sampler block, using the syntax
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

Optionally, give the keyword `defer` after the  to delay generation of the first stage model.

## Examples

The following defines the first stage model given by:

```math
  minimize 100x₁ + 150x₂
    s.t  x₁ + x₂ ≤ 120
         x₁ ≥ 40
         x₂ ≥ 20
```

```jldoctest; setup = :(sp = StochasticProgram(SimpleScenario))
@first_stage sp = begin
    @variable(model, x₁ >= 40)
    @variable(model, x₂ >= 20)
    @objective(model, Min, 100*x₁ + 150*x₂)
    @constraint(model, x₁ + x₂ <= 120)
end

# output

Stochastic program with:
 * 0 scenarios of type SimpleScenario
 * 2 decision variables
 * undefined second stage
Solver is default solver

```

See also: [`@second_stage`](@ref)
"""
macro first_stage(arg) esc(:(@first_stage $arg generate)) end
macro first_stage(arg, defer)
    generate = if defer == :defer
        :false
    elseif defer == :generate
        :true
    else
        error("Unknown option $defer")
    end
    @capture(arg, sp_Symbol = modeldef_) || error("Invalid syntax. Expected: stochasticprogram = begin JuMPdef end")
    vardefs = Expr(:block)
    for line in modeldef.args
        (@capture(line, @constraint(m_Symbol, constdef__)) || @capture(line, @objective(m_Symbol, objdef__))) && continue
        push!(vardefs.args, line)
    end
    code = @q begin
        isa($(esc(sp)), StochasticProgram) || error("Given object is not a stochastic program.")
        if haskey($(esc(sp)).problemcache, :stage_1)
            remove_first_stage!($(esc(sp)))
            remove_subproblems!($(esc(sp)))
            invalidate_cache!($(esc(sp)))
        end
        $(esc(sp)).generator[:stage_1_vars] = ($(esc(:model))::JuMP.Model, $(esc(:stage))) -> begin
            $(esc(vardefs))
	    return $(esc(:model))
        end
        $(esc(sp)).generator[:stage_1] = ($(esc(:model))::JuMP.Model, $(esc(:stage))) -> begin
            $(esc(modeldef))
	    return $(esc(:model))
        end
        if $generate
            generate_stage_one!($(esc(sp)))
        end
        $(esc(sp))
    end
    return prettify(code)
end
"""
    @second_stage(def)

Add a second stage model generation recipe to `stochasticprogram` using the syntax
```julia
@second_stage stochasticprogram::StochasticProgram = begin
    @decision var1 var2 ...
    ...
end [defer]
```
where JuMP syntax is used inside the block to define the second stage model. Annotate each first stage decision that appears in the second stage model with `@decision`. During definition, the second stage model is referenced through the reserved keyword `model` and the scenario specific data is referenced through the reserved keyword `scenario`.

Optionally, give the keyword `defer` after the  to delay generation of the first stage model.

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

```jldoctest
@second_stage sp = begin
    @decision x₁ x₂
    ξ = scenario
    @variable(model, 0 <= y₁ <= ξ.d₁)
    @variable(model, 0 <= y₂ <= ξ.d₂)
    @objective(model, Min, ξ.q₁*y₁ + ξ.q₂*y₂)
    @constraint(model, 6*y₁ + 10*y₂ <= 60*x₁)
    @constraint(model, 8*y₁ + 5*y₂ <= 80*x₂)
end

# output

Stochastic program with:
 * 2 scenarios of type SimpleScenario
 * 2 decision variables
 * 2 recourse variables
Solver is default solver

```

See also: [`@first_stage`](@ref)
"""
macro second_stage(arg) esc(:(@second_stage $arg generate)) end
macro second_stage(arg, defer)
    generate = if defer == :defer
        :false
    elseif defer == :generate
        :true
    else
        error("Unknown option $defer")
    end
    @capture(arg, sp_Symbol = modeldef_) || error("Invalid syntax. Expected stochasticprogram = begin JuMPdef end")
    def = postwalk(modeldef) do x
        @capture(x, @decision args__) || return x
        code = Expr(:block)
        for var in args
            varkey = Meta.quot(var)
            push!(code.args, :($var = parent.objDict[$varkey]))
        end
        return code
    end

    code = @q begin
        isa($(esc(sp)), StochasticProgram) || error("Given object is not a stochastic program.")
        if has_generator($(esc(sp)), :stage_2)
            remove_subproblems!($(esc(sp)))
            invalidate_cache!($(esc(sp)))
        end
        $(esc(sp)).generator[:stage_2] = ($(esc(:model))::JuMP.Model, $(esc(:stage)), $(esc(:scenario))::AbstractScenario, $(esc(:parent))::JuMP.Model) -> begin
            $(esc(def))
	    return $(esc(:model))
        end
        if $generate
            generate_stage_two!($(esc(sp)))
        end
        $(esc(sp))
    end
    return prettify(code)
end
"""
    @decision(def)

Annotate each first stage variable that appears in a @second_stage block, using the syntax
```julia
@decision var1, var2, ...
```

## Examples

```julia
@decision x₁, x₂
```

See also [`@second_stage`](@ref)
"""
macro decision(def) @warn "@decision should be used inside a @first_stage block." end
macro stage(stage,args)
    @capture(args, sp_Symbol = modeldef_) || error("Invalid syntax. Expected stage, multistage = begin JuMPdef end")
    # Save variable definitions separately
    vardefs = Expr(:block)
    for line in modeldef.args
        (@capture(line, @constraint(m_Symbol, constdef__)) || @capture(line, @objective(m_Symbol, objdef__)) || @capture(line, @decision args__)) && continue
        push!(vardefs.args, line)
    end
    # Handle the first stage and the second stages differently
    code = if stage == 1
        code = @q begin
            isa($(esc(sp)), StochasticProgram) || error("Given object is not a stochastic program.")
            $(esc(sp)).generator[:stage_1_vars] = ($(esc(:model))::JuMP.Model,$(esc(:stage))) -> begin
                $(esc(vardefs))
	        return $(esc(:model))
            end
            $(esc(sp)).generator[:stage_1] = ($(esc(:model))::JuMP.Model,$(esc(:stage))) -> begin
                $(esc(modeldef))
	        return $(esc(:model))
            end
            nothing
        end
        code
    else
        def = postwalk(modeldef) do x
            @capture(x, @decision args__) || return x
            code = Expr(:block)
            for var in args
                varkey = Meta.quot(var)
                push!(code.args, :($var = parent.objDict[$varkey]))
            end
            return code
        end
        # Create generator function
        code = @q begin
            isa($(esc(sp)), StochasticProgram) || error("Given object is not a stochastic program.")
            $(esc(sp)).generator[Symbol(:stage_,$stage,:_vars)] = ($(esc(:model))::JuMP.Model, $(esc(:stage)), $(esc(:scenario))) -> begin
                $(esc(vardefs))
	        return $(esc(:model))
            end
            $(esc(sp)).generator[Symbol(:stage_,$stage)] = ($(esc(:model))::JuMP.Model, $(esc(:stage)), $(esc(:scenario))::AbstractScenario, $(esc(:parent))::JuMP.Model) -> begin
                $(esc(def))
	        return $(esc(:model))
            end
            $(esc(sp))
        end
        code
    end
    # Return code
    return prettify(code)
end
# ========================== #
