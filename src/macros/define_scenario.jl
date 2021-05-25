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
