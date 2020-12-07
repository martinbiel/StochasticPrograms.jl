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
    end
    return nothing
end

function generate!(stochasticprogram::StochasticProgram{N}, structure::DeterministicEquivalent{N}, stage::Integer) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    dep_model = structure.model
    if stage == 1
        # Define first-stage problem
        generator(stochasticprogram, :stage_1)(dep_model, stage_parameters(stochasticprogram, 1))
        # Cache first-stage objective
        obj = objective_function(dep_model)
        sense = objective_sense(dep_model)
        push!(structure.sub_objectives[1], (sense, moi_function(obj)))
        # Bookkeeping
        for (objkey, obj) in object_dictionary(dep_model)
            if isa(obj, DecisionRef)
                # Get common index in proxy and add to variable map
                proxy_var = proxy(stochasticprogram, stage)[objkey]
                for s in 2:N
                    # TODO: Update for multi-stage
                    for i in 1:num_scenarios(structure, s)
                        structure.variable_map[(index(proxy_var), i)] = index(obj)
                    end
                end
            elseif isa(obj, AbstractArray{<:DecisionRef})
                # Get common index in proxy
                proxy_var = proxy(stochasticprogram, stage)[objkey]
                for (var, proxy) in zip(obj, proxy_var)
                    # Update variable map
                    for s in 2:N
                        # TODO: Update for multi-stage
                        for i in 1:num_scenarios(structure, s)
                            structure.variable_map[(index(proxy), i)] = index(var)
                        end
                    end
                end
            end
        end
    else
        # Sanity check on scenario probabilities
        if num_scenarios(stochasticprogram, stage) > 0
            p = stage_probability(stochasticprogram, stage)
            abs(p - 1.0) <= 1e-6 || @warn "Scenario probabilities do not add up to one. The probability sum is given by $p"
        end
        # Cache current objective and sense
        dep_obj = objective_function(dep_model)
        obj_sense = objective_sense(dep_model)
        obj_sense = obj_sense == MOI.FEASIBILITY_SENSE ? MOI.MIN_SENSE : obj_sense
        # Null objective temporarily in case subproblem objectives are zero
        @objective(dep_model, obj_sense, 0)
        # Define second-stage problems, renaming variables according to scenario.
        stage_two_params = stage_parameters(stochasticprogram, 2)
        visited_objs = collect(keys(object_dictionary(dep_model)))
        seen_constraints = CI[]
        # Do not need to map any first-stage decision constraints
        for (F,S) in MOI.get(structure.model, MOI.ListOfConstraints())
            if is_decision_type(F)
                append!(seen_constraints, MOI.get(structure.model, MOI.ListOfConstraintIndices{F,S}()))
            end
        end
        # Loop through scenarios and incrementally build deterministic equivalent
        for (i, scenario) in enumerate(scenarios(stochasticprogram))
            # Generate model information for scenario i
            stage_key = Symbol(:stage_, stage)
            generator(stochasticprogram, stage_key)(dep_model, stage_parameters(stochasticprogram, stage), scenario)
            # Update objective and cache the subobjective function for scenario i
            sub_sense = objective_sense(dep_model)
            sub_obj = objective_function(dep_model)
            if obj_sense == sub_sense
                dep_obj += probability(scenario) * objective_function(dep_model)
            else
                dep_obj -= probability(scenario) * objective_function(dep_model)
            end
            push!(structure.sub_objectives[stage], (sub_sense, moi_function(sub_obj)))
            # Bookkeeping for objects added in scenario i
            for (objkey,obj) in filter(kv->kv.first ∉ visited_objs, object_dictionary(dep_model))
                newkey = if isa(obj, VariableRef) || isa(obj, DecisionRef)
                    if isa(obj, DecisionRef)
                        # Get common index in proxy and add to variable map
                        proxy_var = proxy(stochasticprogram, stage)[objkey]
                        structure.variable_map[(index(proxy_var), i)] = index(obj)
                    end
                    # Update variable name to reflect stage and scenario
                    varname = if N > 2
                        varname = add_subscript(add_subscript(JuMP.name(obj), stage), i)
                    else
                        varname = add_subscript(JuMP.name(obj), i)
                    end
                    set_name(obj, varname)
                    # Return new key
                    newkey = Symbol(varname)
                elseif isa(obj, AbstractArray{<:VariableRef}) || isa(obj, AbstractArray{<:DecisionRef})
                    # Update object name to reflect stage and scenario
                    arrayname = if N > 2
                        arrayname = add_subscript(add_subscript(objkey, stage), i)
                    else
                        arrayname = add_subscript(objkey, i)
                    end
                    # Get common indices from proxy
                    proxy_var = proxy(stochasticprogram, stage)[objkey]
                    # Handle each individual variable in array
                    for (var, proxy) in zip(obj, proxy_var)
                        # Update variable map
                        if isa(obj, AbstractArray{<:DecisionRef})
                            structure.variable_map[(index(proxy), i)] = index(var)
                        end
                        # Update variable name to reflect stage and scenario
                        splitname = split(name(var), "[")
                        varname = if N > 2
                            varname = add_subscript(splitname[1], stage)
                        else
                            varname = splitname[1]
                        end
                        set_name(var, @sprintf("%s[%s", add_subscript(varname,i), splitname[2]))
                    end
                    # Return new key
                    newkey = Symbol(arrayname)
                elseif isa(obj, JuMP.ConstraintRef) ||
                       isa(obj, AbstractArray{<:ConstraintRef}) ||
                       isa(obj, AbstractArray{<:GenericAffExpr}) ||
                       isa(obj, AbstractArray{<:DecisionAffExpr})
                    # Update obj name to reflect stage and scenario
                    arrayname = if N > 2
                        arrayname = add_subscript(add_subscript(objkey, stage), i)
                    else
                        arrayname = add_subscript(objkey, i)
                    end
                    # Return new key
                    newkey = Symbol(arrayname)
                elseif isa(obj, AbstractJuMPScalar)
                    # Update obj name to reflect stage and scenario
                    exprname = if N > 2
                        exprname = add_subscript(add_subscript(objkey, stage), i)
                    else
                        exprname = add_subscript(objkey, i)
                    end
                    # Return new key
                    newkey = Symbol(exprname)
                else
                    continue
                end
                # Change name of obj to newkey to avoid collisions
                dep_model.obj_dict[newkey] = obj
                delete!(dep_model.obj_dict, objkey)
                # Bookkeep newkey to avoid handling again
                push!(visited_objs, newkey)
            end
            # Update constraint map
            for (F,S) in MOI.get(proxy(stochasticprogram, stage), MOI.ListOfConstraints())
                if is_decision_type(F)
                    constraints =  filter(MOI.get(structure.model, MOI.ListOfConstraintIndices{F,S}())) do ci
                        !(ci in seen_constraints)
                    end
                    proxy_constraints = MOI.get(proxy(stochasticprogram, stage), MOI.ListOfConstraintIndices{F,S}())
                    for (proxy,ci) in zip(proxy_constraints, constraints)
                        structure.constraint_map[(proxy, i)] = typeof(ci)(ci.value)
                        push!(seen_constraints, ci)
                    end
                end
            end
        end
        # Update objective
        set_objective_function(dep_model, dep_obj)
        set_objective_sense(dep_model, obj_sense)
    end
    return nothing
end

function clear!(dep::DeterministicEquivalent)
    # Clear decisions
    map(clear!, dep.decisions)
    # Clear subobjectives
    map(empty!, dep.sub_objectives)
    # Clear deterministic equivalent model
    empty!(dep.model)
    return nothing
end
