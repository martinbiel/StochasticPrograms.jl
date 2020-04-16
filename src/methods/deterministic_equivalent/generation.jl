# Deterministic equivalent generation #
# ========================== #
function generate!(stochasticprogram::TwoStageStochasticProgram, structure::DeterministicEquivalent{2}) where N
    # Check that the required generators have been defined
    has_generator(stochasticprogram, :stage_1) || error("First-stage problem not defined in stochastic program. Consider @stage 1.")
    has_generator(stochasticprogram, :stage_2) || error("Second-stage problem not defined in stochastic program. Consider @stage 2.")
    # Create deterministic equivalent
    _generate_deterministic_equivalent!(stochasticprogram, structure.model)
    return stochasticprogram
end

function _generate_deterministic_equivalent!(stochasticprogram::TwoStageStochasticProgram, dep_model::JuMP.Model)
    # Define first-stage problem
    generator(stochasticprogram, :stage_1)(dep_model, stage_parameters(stochasticprogram, 1))
    dep_obj = objective_function(dep_model)
    # Define second-stage problems, renaming variables according to scenario.
    stage_two_params = stage_parameters(stochasticprogram, 2)
    visited_objs = collect(keys(object_dictionary(dep_model)))
    for (i, scenario) in enumerate(scenarios(stochasticprogram))
        generator(stochasticprogram,:stage_2)(dep_model, stage_two_params, scenario)
        dep_obj += probability(scenario)*objective_function(dep_model)
        for (objkey,obj) ∈ filter(kv->kv.first ∉ visited_objs, object_dictionary(dep_model))
            newkey = if isa(obj, VariableRef)
                varname = add_subscript(name(obj), i)
                set_name(obj, varname)
                newkey = Symbol(varname)
            elseif isa(obj, AbstractArray{<:VariableRef})
                arrayname = add_subscript(objkey, i)
                for var in obj
                    splitname = split(name(var), "[")
                    varname = @sprintf("%s[%s", add_subscript(splitname[1],i), splitname[2])
                    set_name(var, varname)
                end
                newkey = Symbol(arrayname)
            elseif isa(obj,JuMP.ConstraintRef)
                arrayname = add_subscript(objkey, i)
                newkey = Symbol(arrayname)
            elseif isa(obj, AbstractArray{<:ConstraintRef})
                arrayname = add_subscript(objkey, i)
                newkey = Symbol(arrayname)
            else
                continue
            end
            dep_model.obj_dict[newkey] = obj
            delete!(dep_model.obj_dict, objkey)
            push!(visited_objs, newkey)
        end
    end
    set_objective_function(dep_model, dep_obj)
    return dep_model
end
