# Creation macros #
# ========================== #
"""
    @scenario(def)

Define a scenario type compatible with StochasticProgramsusing the syntax
```julia
@scenario name = begin
    var::vartype
    ...

    [function expected(scenarios)
        ...
     end]
end
```
The generated type is referenced through [name]Scenario and a default constructor is available. In addition, the keyword `probability` can be given in the constructor to set the probability of the scenario occuring. If possible, an `expected` method will be generated for the defined type. The defined scenario type will be available on all Julia processes.

[If desired]/[if it is not possible to generate], an `expected` method implementation [can]/[should] be given.

## Examples

The following defines a simple scenario
```math
  ξ = (d₁ d₂ q₁ q₂)ᵀ
```

```jldoctest
@scenario Simple = begin
    q₁::Float64
    q₂::Float64
    d₁::Float64
    d₂::Float64
end

s₁ = SimpleScenario(-24.0, -28.0, 500.0, 100.0, probability = 0.4)

# output

SimpleScenario(Probability(0.4), -24.0, -28.0, 500.0, 100.0)

```

See also: [`@sampler`](@ref), [`@second_stage`](@ref)
"""
macro scenario(arg)
    @capture(arg, name_Symbol = scenariodef_) || error("Invalid syntax. Expected: scenarioname = begin scenariodef end")
    scenarioname = Symbol(name, :Scenario)
    vars = Vector{Symbol}()
    vartypes = Vector{Union{Expr,Symbol}}()
    vardefs = Vector{Expr}()
    expectdefs = Vector{Expr}()
    def = Expr(:block)
    for line in scenariodef.args
        if @capture(line, var_Symbol::vartype_)
            push!(vars, var)
            push!(vartypes, vartype)
            push!(vardefs, line)
            push!(def.args, line)
        elseif @capture(line, function expect_Symbol(scenarios::Vector{$scenarioname}) body_ end) && expect == :expected
            push!(expectdefs, line)
        end
    end
    # Handle expectation definition
    if length(expectdefs) > 1
        error("Only provide one expectation implementation")
    end
    expectdef = if length(expectdefs) == 1
        expectdef = expectdefs[1]
        expectdef.args[1].args[1] = :(StochasticPrograms.expected)
        expectdef
    else
        Expr(:block)
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
        @everywhere begin
            provided_def = length($expectdefs) == 1
            if StochasticPrograms.supports_expected([$(vartypes...)], provided_def) || provided_def
                struct $scenarioname <: AbstractScenario
                    probability::Probability
                    $def

                    function (::Type{$scenarioname})($(vardefs...); probability::AbstractFloat = 0.5)
                        return new(Probability(probability), $(vars...))
                    end
                end
                if provided_def
                    $expectdef
                else
                    function StochasticPrograms.expected(scenarios::Vector{$scenarioname})
                        isempty(scenarios) && return $scenarioname(zero.([$(vartypes...)])...; probability = 1.0)
                        return reduce(scenarios) do s1, s2
                            $combine
                        end
                    end
                end
            else
                @warn "The scenario type $(string($(Meta.quot(name)))) was not defined. A user-provided implementation \n\n    function expected(scenarios::Vector{$(string($(Meta.quot(scenarioname))))})\n        ...\n    end\n\nis required."
            end
        end
    end
    return prettify(code)
end
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
Any internal state required by the sampler, as well as any specialized constructor, are defined in the @sampler block as they would be in any Julia struct. The sampler operation should be defined inside the @sample block, which should return a sampled `scenario`. Inside the @sample block, the sampler object is referenced through the reserved keyword `sampler`. The defined sampler will be available on all Julia processes.

Optionally, give a `samplername` to the sampler. Otherwise, it will be named [scenario]Sampler.

## Examples

The following defines a simple dummy sampler, with some internal weight value, for the scenario defined in ?@scenario, and samples one scenario.

```jldoctest
@sampler Simple = begin
    w::Float64

    Simple(w::AbstractFloat) = new(w)

    @sample begin
        w = sampler.w
        return SimpleScenario(-24.0 + w*randn(), -28.0 + w*randn(), 500.0, 100.0, probability = rand())
    end
end
s = SimpleSampler(2.0)
s()

# output

SimpleScenario(Probability(0.29), -19.93, -28.28, 500.0, 100.0)

```

See also: [`@scenario`](@ref)
"""
macro sampler(arg) :(@sampler(nothing, $arg)) end
macro sampler(name, arg)
    @capture(arg, sname_Symbol = samplerdef_) || error("Invalid syntax. Expected: scenarioname = begin samplerdef end")
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
        @everywhere begin
            struct $samplername <: AbstractSampler{$scenarioname}
                $def
            end

            function (sampler::$samplername)()
                $sampledef
            end
        end
    end
    return prettify(code)
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

Optionally, give the keyword `defer` after the  to delay generation of the first stage model.

## Examples

The following defines the first stage model given by:

```math
  minimize 100x₁ + 150x₂
    s.t  x₁ + x₂ ≤ 120
         x₁ ≥ 40
         x₂ ≥ 20
```

```jldoctest def
@first_stage sp = begin
    @variable(model, x₁ >= 40)
    @variable(model, x₂ >= 20)
    @objective(model, Min, 100*x₁ + 150*x₂)
    @constraint(model, x₁ + x₂ <= 120)
end

# output

Stochastic program with:
 * 2 decision variables
 * 0 scenarios
 * 0 second stage models
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
        haskey($(esc(sp)).problemcache, :stage_1) && remove_first_stage!($(esc(sp)))
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

```jldoctest def
@second_stage sp = begin
    @decision x₁ x₂
    ξ = scenario
    @variable(model, 0 <= y₁ <= ξ.d₁)
    @variable(model, 0 <= y₂ <= ξ.d₂)
    @objective(model, Min, ξ.q₁*y₁ + ξ.q₂*y₂)
    @constraint(model, 6*y₁ + 10*y₂ <= 60*x₁)
    @constraint(model, 8*y₁ + 5*y₂ <= 80*x₂)
end
s₁ = SimpleScenario(-24.0, -28.0, 500.0, 100.0, probability = 0.4)
s₂ = SimpleScenario(-28.0, -32.0, 300.0, 300.0, probability = 0.6)
add_scenarios!(sp, [s₁, s₂])

# output

Stochastic program with:
 * 2 decision variables
 * 2 scenarios
 * 2 second stage models
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
        has_generator($(esc(sp)), :stage_2) && remove_subproblems!($(esc(sp)))
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
