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
