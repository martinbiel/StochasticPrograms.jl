# Deterministic equivalent generation #
# ========================== #
function generate!(stochasticprogram::StochasticProgram{N}, structure::DeterministicEquivalent{N}) where N
    # Set the optimizer
    structure.model.moi_backend = optimizer(stochasticprogram)
    # Prepare decisions
    structure.model.ext[:decisions] = structure.decisions
    add_decision_bridges!(structure.model)
    # Generate all stages
    for stage in 1:N
        generate!(stochasticprogram, structure, stage)
        # Register stage decisions
        if stage < N
            append!(structure.decision_variables[stage], all_decision_variables(structure.model))
            for previous_stage in structure.decision_variables[1:stage-1]
                filter!(d -> d ∈ previous_stage, structure.decision_variables[stage])
            end
        end
    end
    return nothing
end

function generate!(stochasticprogram::StochasticProgram{N}, structure::DeterministicEquivalent{N}, stage::Integer) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    dep_model = structure.model
    if stage == 1
        # Define first-stage problem
        generator(stochasticprogram, :stage_1)(dep_model, stage_parameters(stochasticprogram, 1))
    else
        # Sanity check on scenario probabilities
        if num_scenarios(stochasticprogram, stage) > 0
            p = stage_probability(stochasticprogram, stage)
            abs(p - 1.0) <= 1e-6 || @warn "Scenario probabilities do not add up to one. The probability sum is given by $p"
        end
        # Cache current objective
        dep_obj = objective_function(dep_model)
        obj_sense = objective_sense(dep_model)
        obj_sense = obj_sense == MOI.FEASIBILITY_SENSE ? MOI.MIN_SENSE : obj_sense
        # Define second-stage problems, renaming variables according to scenario.
        stage_two_params = stage_parameters(stochasticprogram, 2)
        visited_objs = collect(keys(object_dictionary(dep_model)))
        for (i, scenario) in enumerate(scenarios(stochasticprogram))
            stage_key = Symbol(:stage_, stage)
            generator(stochasticprogram, stage_key)(dep_model, stage_parameters(stochasticprogram, stage), scenario)
            sub_sense = objective_sense(dep_model)
            sub_obj = objective_function(dep_model)
            if obj_sense == sub_sense
                add_to_expression!(dep_obj, probability(scenario) * objective_function(dep_model))
                push!(structure.sub_objectives[stage - 1], moi_function(sub_obj))
            else
                add_to_expression!(dep_obj, -probability(scenario) * objective_function(dep_model))
                push!(structure.sub_objectives[stage - 1], -moi_function(sub_obj))
            end
            for (objkey,obj) ∈ filter(kv->kv.first ∉ visited_objs, object_dictionary(dep_model))
                newkey = if isa(obj, VariableRef) || isa(obj, DecisionRef)
                    varname = if N > 2
                        varname = add_subscript(add_subscript(JuMP.name(obj), stage), i)
                    else
                        varname = add_subscript(JuMP.name(obj), i)
                    end
                    set_name(obj, varname)
                    newkey = Symbol(varname)
                elseif isa(obj, AbstractArray{<:VariableRef}) || isa(obj, AbstractArray{<:DecisionRef})
                    arrayname = if N > 2
                        arrayname = add_subscript(add_subscript(objkey, stage), i)
                    else
                        arrayname = add_subscript(objkey, i)
                    end
                    for var in obj
                        splitname = split(name(var), "[")
                        varname = if N > 2
                            varname = add_subscript(splitname[1], stage)
                        else
                            varname = splitname[1]
                        end
                        set_name(var, @sprintf("%s[%s", add_subscript(varname,i), splitname[2]))
                    end
                    newkey = Symbol(arrayname)
                elseif isa(obj, JuMP.ConstraintRef)
                    arrayname = if N > 2
                        arrayname = add_subscript(add_subscript(objkey, stage), i)
                    else
                        arrayname = add_subscript(objkey, i)
                    end
                    newkey = Symbol(arrayname)
                elseif isa(obj, AbstractArray{<:ConstraintRef})
                    arrayname = if N > 2
                        arrayname = add_subscript(add_subscript(objkey, stage), i)
                    else
                        arrayname = add_subscript(objkey, i)
                    end
                    newkey = Symbol(arrayname)
                elseif isa(obj, AbstractJuMPScalar)
                    exprname = if N > 2
                        exprname = add_subscript(add_subscript(objkey, stage), i)
                    else
                        exprname = add_subscript(objkey, i)
                    end
                    newkey = Symbol(exprname)
                else
                    continue
                end
                dep_model.obj_dict[newkey] = obj
                delete!(dep_model.obj_dict, objkey)
                push!(visited_objs, newkey)
            end
        end
        set_objective_function(dep_model, dep_obj)
        set_objective_sense(dep_model, obj_sense)
    end
    return nothing
end

function clear!(dep::DeterministicEquivalent)
    # Clear deterministic equivalent model
    empty!(dep.model)
    return nothing
end
