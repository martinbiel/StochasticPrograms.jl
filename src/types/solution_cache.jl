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

const CachableModel = Union{MOI.ModelLike, AbstractStochasticStructure}

struct SolutionCache{M <: MOI.ModelLike} <: MOI.ModelLike
    modattr::Dict{MOI.AbstractModelAttribute, Any}
    varattr::Dict{MOI.AbstractVariableAttribute, Dict{VI, Any}}
    conattr::Dict{MOI.AbstractConstraintAttribute, Dict{CI, Any}}

    function SolutionCache(model::MOI.ModelLike)
        M = typeof(model)
        cache = new{M}(Dict{MOI.AbstractModelAttribute, Any}(),
                       Dict{MOI.AbstractVariableAttribute, Dict{VI, Any}}(),
                       Dict{MOI.AbstractConstraintAttribute, Dict{CI, Any}}())
        return cache
    end

    function SolutionCache(model::MOI.ModelLike, variables::Vector{<:VI}, constraints::Vector{<:CI})
        M = typeof(model)
        cache = new{M}(Dict{MOI.AbstractModelAttribute, Any}(),
                       Dict{MOI.AbstractVariableAttribute, Dict{VI, Any}}(),
                       Dict{MOI.AbstractConstraintAttribute, Dict{CI, Any}}())
        cache_model_attributes!(cache, model)
        cache_variable_attributes!(cache, model, variables)
        cache_constraint_attributes!(cache, model, constraints)
        return cache
    end
end

function cache_model_attributes!(cache::SolutionCache, src::CachableModel)
    attributes = [MOI.ObjectiveValue(),
                  MOI.DualObjectiveValue(),
                  MOI.ObjectiveBound(),
                  MOI.RelativeGap(),
                  MOI.SolveTime(),
                  MOI.SimplexIterations(),
                  MOI.BarrierIterations(),
                  MOI.NodeCount(),
                  MOI.TerminationStatus(),
                  MOI.RawStatusString(),
                  MOI.PrimalStatus(),
                  MOI.DualStatus()]
    for attr in attributes
        try
            value = MOI.get(src, attr)
            MOI.set(cache, attr, value)
        catch
        end
    end
    return nothing
end

function cache_model_attributes!(cache::SolutionCache, src::CachableModel, stage::Integer, scenario_index::Integer)
    attributes = [MOI.ObjectiveValue(),
                  MOI.DualObjectiveValue(),
                  MOI.ObjectiveBound(),
                  MOI.RelativeGap(),
                  MOI.SolveTime(),
                  MOI.SimplexIterations(),
                  MOI.BarrierIterations(),
                  MOI.NodeCount(),
                  MOI.TerminationStatus(),
                  MOI.RawStatusString(),
                  MOI.PrimalStatus(),
                  MOI.DualStatus()]
    for attr in attributes
        try
            value = MOI.get(src, ScenarioDependentModelAttribute(stage, scenario_index, attr))
            MOI.set(cache, attr, value)
        catch
        end
    end
    return nothing
end

function cache_variable_attributes!(cache::SolutionCache, src::CachableModel, variables::Vector{<:VI})
    attr = MOI.VariablePrimal()
    for vi in variables
        try
            value = MOI.get(src, attr, vi)
            MOI.set(cache, attr, vi, value)
        catch
        end
    end
    return nothing
end
function cache_variable_attributes!(cache::SolutionCache, src::CachableModel)
    variables = MOI.get(src, MOI.ListOfVariableIndices())
    cache_variable_attributes!(cache, src, variables)
    return nothing
end
function cache_variable_attributes!(cache::SolutionCache, src::CachableModel, variables::Vector{<:VI}, stage::Integer, scenario_index::Integer)
    attr = MOI.VariablePrimal()
    for vi in variables
        try
            value = MOI.get(src, ScenarioDependentVariableAttribute(stage, scenario_index, attr), vi)
            MOI.set(cache, attr, vi, value)
        catch
        end
    end
    return nothing
end

function cache_constraint_attributes!(cache::SolutionCache, src::CachableModel, constraints::Vector{<:CI})
    conattrs = [MOI.ConstraintPrimal(), MOI.ConstraintDual(), MOI.ConstraintBasisStatus()]
    for ci in constraints
        for attr in conattrs
            try
                value = MOI.get(src, attr, ci)
                MOI.set(cache, attr, ci, value)
            catch
            end
        end
    end
    return nothing
end
function cache_constraint_attributes!(cache::SolutionCache, src::CachableModel)
    ctypes = filter(t -> is_decision_type(t[1]), MOI.get(src, MOI.ListOfConstraints()))
    constraints = mapreduce(vcat, ctypes) do (F, S)
        return MOI.get(src, MOI.ListOfConstraintIndices{F,S}())
    end
    cache_constraint_attributes!(cache, src, constraints)
    return nothing
end
function cache_constraint_attributes!(cache::SolutionCache, src::CachableModel, constraints::Vector{<:CI}, stage::Integer, scenario_index::Integer)
    conattrs = [MOI.ConstraintPrimal(), MOI.ConstraintDual(), MOI.ConstraintBasisStatus()]
    for ci in constraints
        for attr in conattrs
            try
                value = MOI.get(src, ScenarioDependentConstraintAttribute(stage, scenario_index, attr), ci)
                MOI.set(cache, attr, ci, value)
            catch
            end
        end
    end
    return nothing
end

function MOI.get(cache::SolutionCache{M},
                 attr::MOI.AbstractModelAttribute) where M
    if !haskey(cache.modattr, attr)
        throw(ArgumentError("Origin model type $M did not support accessing the attribute $attr"))
    end
    return cache.modattr[attr]
end

function MOI.get(cache::SolutionCache{M},
                 attr::MOI.AbstractVariableAttribute,
                 vi::VI) where M
    attribute_dict = get(cache.varattr, attr, nothing)
    if attribute_dict === nothing
        throw(ArgumentError("Origin model type $M did not support accessing the attribute $attr"))
    end
    if !haskey(attribute_dict, vi)
        throw(ArgumentError("Origin model type $M did not support accessing the attribute $attr"))
    end
    return get(attribute_dict, vi, nothing)
end

function MOI.get(cache::SolutionCache{M},
                 attr::MOI.AbstractConstraintAttribute,
                 ci::CI) where M
    attribute_dict = get(cache.conattr, attr, nothing)
    if attribute_dict === nothing
        throw(ArgumentError("Origin model type $M did not support accessing the attribute $attr"))
    end
    if !haskey(attribute_dict, ci)
        throw(ArgumentError("Origin model type $M did not support accessing the attribute $attr"))
    end
    return get(attribute_dict, ci, nothing)
end

function MOI.set(cache::SolutionCache,
                 attr::MOI.AbstractModelAttribute,
                 value)
    cache.modattr[attr] = value
    return nothing
end

function MOI.set(cache::SolutionCache,
                 attr::MOI.AbstractVariableAttribute,
                 vi::VI,
                 value)
    if !haskey(cache.varattr, attr)
        cache.varattr[attr] = Dict{VI, Any}()
    end
    cache.varattr[attr][vi] = value
    return nothing
end

function MOI.set(cache::SolutionCache,
                 attr::MOI.AbstractConstraintAttribute,
                 ci::CI,
                 value)
    if !haskey(cache.conattr, attr)
        cache.conattr[attr] = Dict{VI, Any}()
    end
    cache.conattr[attr][ci] = value
    return nothing
end

MOI.supports(::SolutionCache, ::MOI.AbstractModelAttribute) = true
MOI.supports(::SolutionCache, ::Union{MOI.AbstractVariableAttribute, MOI.AbstractConstraintAttribute}, ::Type{<:MOI.Index}) = true
