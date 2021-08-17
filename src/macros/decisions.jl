# MIT License
#
# Copyright (c) 2018 Martin Biel
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

"""
    @decision(model, expr, args..., kw_args...)

Add a decision variable to `model` described by the expression `expr`. If used inside a [`@stage`](@ref) block, the created variable can be used in subsequent stage blocks. [`@recourse`](@ref) should be used to mark decisions in the final stage. See `@variable` for syntax details.

## Examples

```julia
@decision(model, x >= 40)
```

See also [`@recourse`](@ref), [`@parameters`](@ref), [`@uncertain`](@ref), [`@stage`](@ref)
"""
macro decision(def...) @warn "@decision should be used inside a @stage block." end
"""
    @recourse(model, expr, args..., kw_args...)

Add a recourse decision variable to `model` described by the expression `expr`. Replaces [`@decision`](@ref) in the [`@stage`](@ref) block of the final stage, and can only be used there. See `@variable` for syntax details.

## Examples

```julia
@recourse(model, 0 <= y <= 1)
```

See also [`@decision`](@ref), [`@parameters`](@ref), [`@uncertain`](@ref), [`@stage`](@ref)
"""
macro recourse(def...) @warn "@recourse should be used inside the @stage block of the final stage." end
macro _decision(args...)
    args = [args...]
    known = false
    recourse = false
    # Check context of decision definition
    if args[1] isa Symbol && args[1] == :known
        known = true
    elseif args[1] isa Symbol && args[1] == :recourse
        recourse = true
    else
        args[1] == :decision || error("Incorrect usage of @_decision.")
    end
    # Remove context from args
    deleteat!(args, 1)
    # Cache stage and remove from args
    stage = args[1]
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
        return esc(:(@variable $((args)...) set = StochasticPrograms.KnownSet($stage)))
    else
        return esc(:(@variable $((args)...) set = StochasticPrograms.DecisionSet($stage, constraint = $set, is_recourse = $recourse)))
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
macro known(model_name, args...)
    code = Expr(:block)
    for var in args
        varkey = Meta.quot(var)
        push!(code.args, :($(esc(var)) = $(esc(model_name))[$varkey]))
    end
    return code
end
