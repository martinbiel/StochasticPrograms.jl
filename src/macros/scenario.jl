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
                        size(ξ.data) == size($(esc(val))) || error("Dimensions of right hand side in @scenario assignment differ from left hand side.")
                    elseif ξ.data isa DenseAxisArray
                        ξ.data.data .= $(esc(val))
                    elseif ξ.data isa SparseAxisArray
                        length(ξ.data.data) == length($(esc(val))) || error("Dimensions of right hand side in @scenario assignment differ from left hand side.")
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
