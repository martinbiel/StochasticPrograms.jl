struct SolutionCache{M <: MOI.ModelLike} <: MOI.ModelLike
    optattr::Dict{MOI.AbstractOptimizerAttribute, Any}
    modattr::Dict{MOI.AbstractModelAttribute, Any}
    varattr::Dict{MOI.AbstractVariableAttribute, Dict{VI, Any}}
    conattr::Dict{MOI.AbstractConstraintAttribute, Dict{CI, Any}}

    function SolutionCache(model::MOI.ModelLike)
        M = typeof(model)
        cache = new{M}(Dict{MOI.AbstractOptimizerAttribute, Any}(),
                       Dict{MOI.AbstractModelAttribute, Any}(),
                       Dict{MOI.AbstractVariableAttribute, Dict{VI, Any}}(),
                       Dict{MOI.AbstractConstraintAttribute, Dict{CI, Any}}())
        load_solution!(cache, model)
        return cache
    end
end

function load_solution!(cache::SolutionCache, src::MOI.ModelLike)
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
    attr = MOI.VariablePrimal()
    try
        for vi in MOI.get(src, MOI.ListOfVariableIndices())
            try
                value = MOI.get(src, attr, vi)
                MOI.set(cache, attr, vi, value)
            catch
            end
        end
    catch
    end
    conattrs = [MOI.ConstraintPrimal(), MOI.ConstraintDual(), MOI.ConstraintBasisStatus()]
    try
        for (F, S) in MOI.get(src, MOI.ListOfConstraints())
            for ci in MOI.get(src, MOI.ListOfConstraintIndices{F,S}())
                for attr in conattrs
                    try
                        value = MOI.get(src, attr, ci)
                        MOI.set(cache, attr, ci, value)
                    catch
                    end
                end
            end
        end
    catch
    end
    return nothing
end

function MOI.get(cache::SolutionCache{M},
                 attr::MOI.AbstractOptimizerAttribute) where M
    if !haskey(cache.optattr, attr)
        throw(ArgumentError("Origin model type $M did not support accessing the attribute $attr"))
    end
    return cache.optattr[attr]
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
                 attr::MOI.AbstractOptimizerAttribute,
                 value)
    cache.optattr[attr] = value
    return nothing
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

MOI.supports(::SolutionCache, ::Union{MOI.AbstractModelAttribute, MOI.AbstractOptimizerAttribute}) = true
MOI.supports(::SolutionCache, ::Union{MOI.AbstractVariableAttribute, MOI.AbstractConstraintAttribute}, ::Type{<:MOI.Index}) = true
