# Creation macros #
# ========================== #
"""
    @first_stage(def)

Add a first stage model generation recipe to `stochasticprogram` using the syntax
```julia
@first_stage stochasticprogram::StochasticProgram = begin
    ...
end
```
where JuMP syntax is used inside the block to define the first stage model. During definition, the first stage model is referenced through the reserved keyword `model`.

Optionally, give the keyword `defer` after the  to delay generation of the first stage model.

## Examples

The following defines the following first stage model:
```math
  minimize 100x₁ + 150x₂
    s.t  x₁ + x₂ ≤ 120
         x₁ ≥ 40
         x₂ ≥ 20
```

```jldoctest
julia> @first_stage simple = begin
           @variable(model, x₁ >= 40)
           @variable(model, x₂ >= 20)
           @objective(model, Min, 100*x₁ + 150*x₂)
           @constraint(model, x₁+x₂ <= 120)
       end
```

The following defines the same first stage model, but defers generation.

```jldoctest
julia> @first_stage simple = begin
           @variable(model, x₁ >= 40)
           @variable(model, x₂ >= 20)
           @objective(model, Min, 100*x₁ + 150*x₂)
           @constraint(model, x₁+x₂ <= 120)
       end defer
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
    @capture(arg, model_Symbol = modeldef_) || error("Invalid syntax. Expected: stochasticprogram = begin JuMPdef end")
    vardefs = Expr(:block)
    for line in modeldef.args
        (@capture(line, @constraint(m_Symbol, constdef__)) || @capture(line, @objective(m_Symbol, objdef__))) && continue
        push!(vardefs.args, line)
    end
    code = @q begin
        isa($(esc(model)), StochasticProgram) || error("Given object is not a stochastic program.")
        haskey($(esc(model)).problemcache, :stage_1) && delete!($(esc(model)).problemcache, :stage_1)
        $(esc(model)).generator[:stage_1_vars] = ($(esc(:model))::JuMP.Model, $(esc(:stage))) -> begin
            $(esc(vardefs))
	    return $(esc(:model))
        end
        $(esc(model)).generator[:stage_1] = ($(esc(:model))::JuMP.Model, $(esc(:stage))) -> begin
            $(esc(modeldef))
	    return $(esc(:model))
        end
        if $generate
            generate_stage_one!($(esc(model)))
        end
        $(esc(model))
    end
    return code
end

"""
    @second_stage(def)

Add a second stage model generation recipe to `stochasticprogram` using the syntax
```julia
@second_stage stochasticprogram::StochasticProgram = begin
    @decision var1 var2 ...
    ...
end
```
where JuMP syntax is used inside the block to define the second stage model. Annotate each first stage decision that appears in the second stage model with `@decision`. During definition, the second stage model is referenced through the reserved keyword `model` and the scenario specific data is referenced through the reserved keyword `scenario`.

Optionally, give the keyword `defer` after the  to delay generation of the first stage model.

## Examples

The following defines the following second stage model:
```math
  minimize q₁(ξ)y₁ + q₂(ξ)y₂
    s.t  6y₁ + 10y₂ ≤ 60x₁
         8y₁ + 5y₂ ≤ 60x₂
         0 ≤ y₁ ≤ d₁(ξ)
         0 ≤ y₂ ≤ d₂(ξ)
```
where ``q₁(ξ), q₂(ξ), d₁(ξ), d₂(ξ)`` depend on the scenario ``ξ`` and ``x₁, x₂`` are first stage variables.

```jldoctest
julia> @second_stage simple = begin
           @decision x₁ x₂
           q₁, q₂, d₁, d₂ = ξ.q[1], ξ.q[2], ξ.d[1], ξ.d[2]
           @variable(model, 0 <= y₁ <= d₁)
           @variable(model, 0 <= y₂ <= d₂)
           @objective(model, Min, q₁*y₁ + q₂*y₂)
           @constraint(model, 6*y₁ + 10*y₂ <= 60*x₁)
           @constraint(model, 8*y₁ + 5*y₂ <= 80*x₂)
       end
```

The following defines the same second stage model, but defers generation.

```jldoctest
julia> @second_stage simple = begin
           @decision x₁ x₂
           q₁, q₂, d₁, d₂ = ξ.q[1], ξ.q[2], ξ.d[1], ξ.d[2]
           @variable(model, 0 <= y₁ <= d₁)
           @variable(model, 0 <= y₂ <= d₂)
           @objective(model, Min, q₁*y₁ + q₂*y₂)
           @constraint(model, 6*y₁ + 10*y₂ <= 60*x₁)
           @constraint(model, 8*y₁ + 5*y₂ <= 80*x₂)
       end defer
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
    @capture(arg, model_Symbol = modeldef_) || error("Invalid syntax. Expected stochasticprogram = begin JuMPdef end")
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
        isa($(esc(model)), StochasticProgram) || error("Given object is not a stochastic program.")
        has_generator($(esc(model)), :stage_2) && remove_subproblems!($(esc(model)))
        $(esc(model)).generator[:stage_2] = ($(esc(:model))::JuMP.Model, $(esc(:stage)), $(esc(:scenario))::AbstractScenarioData, $(esc(:parent))::JuMP.Model) -> begin
            $(esc(def))
	    return $(esc(:model))
        end
        if $generate
            generate_stage_two!($(esc(model)))
        end
        $(esc(model))
    end
    return prettify(code)
end

macro stage(stage,args)
    @capture(args, model_Symbol = modeldef_) || error("Invalid syntax. Expected stage, multistage = begin JuMPdef end")
    # Save variable definitions separately
    vardefs = Expr(:block)
    for line in modeldef.args
        (@capture(line, @constraint(m_Symbol, constdef__)) || @capture(line, @objective(m_Symbol, objdef__)) || @capture(line, @decision args__)) && continue
        push!(vardefs.args, line)
    end
    # Handle the first stage and the second stages differently
    code = if stage == 1
        code = @q begin
            isa($(esc(model)), StochasticProgram) || error("Given object is not a stochastic program.")
            $(esc(model)).generator[:stage_1_vars] = ($(esc(:model))::JuMP.Model,$(esc(:stage))) -> begin
                $(esc(vardefs))
	        return $(esc(:model))
            end
            $(esc(model)).generator[:stage_1] = ($(esc(:model))::JuMP.Model,$(esc(:stage))) -> begin
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
            isa($(esc(model)), StochasticProgram) || error("Given object is not a stochastic program.")
            $(esc(model)).generator[Symbol(:stage_,$stage,:_vars)] = ($(esc(:model))::JuMP.Model, $(esc(:stage)), $(esc(:scenario))) -> begin
                $(esc(vardefs))
	        return $(esc(:model))
            end
            $(esc(model)).generator[Symbol(:stage_,$stage)] = ($(esc(:model))::JuMP.Model, $(esc(:stage)), $(esc(:scenario))::AbstractScenarioData, $(esc(:parent))::JuMP.Model) -> begin
                $(esc(def))
	        return $(esc(:model))
            end
            $(esc(model))
        end
        code
    end
    # Return code
    return prettify(code)
end
# ========================== #
