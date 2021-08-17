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

# Deterministic equivalent generation #
# =================================== #
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
    else
        # Sanity check on scenario probabilities
        if num_scenarios(stochasticprogram, stage) > 0
            p = stage_probability(stochasticprogram, stage)
            abs(p - 1.0) <= 1e-6 || @warn "Scenario probabilities do not add up to one. The probability sum is given by $p"
        end
        # Cache current objective and sense
        dep_obj = objective_function(dep_model)
        # Convert DecisionRef to DecisionAffExpr
        dep_obj = 1*dep_obj
        obj_sense = objective_sense(dep_model)
        obj_sense = obj_sense == MOI.FEASIBILITY_SENSE ? MOI.MIN_SENSE : obj_sense
        # Null objective temporarily in case subproblem objectives are zero
        @objective(dep_model, obj_sense, 0)
        # Define second-stage problems, renaming variables according to scenario.
        stage_two_params = stage_parameters(stochasticprogram, 2)
        visited_objs = collect(keys(object_dictionary(dep_model)))
        # Loop through scenarios and incrementally build deterministic equivalent
        for (i, scenario) in enumerate(scenarios(stochasticprogram))
            # Generate model information for scenario i
            stage_key = Symbol(:stage_, stage)
            generator(stochasticprogram, stage_key)(dep_model, stage_parameters(stochasticprogram, stage), scenario)
            # Update objective and cache the subobjective function for scenario i
            (sub_sense, sub_obj) = get_stage_objective(dep_model, 2, i, Val{N}())
            if obj_sense == sub_sense
                JuMP.add_to_expression!(dep_obj, probability(scenario), sub_obj)
            else
                JuMP.add_to_expression!(dep_obj, -probability(scenario), sub_obj)
            end
            # Bookkeeping for objects added in scenario i
            for (objkey,obj) in filter(kv->kv.first ∉ visited_objs, object_dictionary(dep_model))
                newkey = if isa(obj, VariableRef) || isa(obj, DecisionRef)
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
                    # Handle each individual variable in array
                    for var in obj
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
                elseif isa(obj, JuMP.ConstraintRef)
                    # Update constraint name to reflect stage and scenario
                    conname = if N > 2
                        conname = add_subscript(add_subscript(JuMP.name(obj), stage), i)
                    else
                        conname = add_subscript(JuMP.name(obj), i)
                    end
                    set_name(obj, conname)
                    # Return new key
                    newkey = Symbol(conname)
                elseif isa(obj, AbstractArray{<:ConstraintRef}) ||
                       isa(obj, AbstractArray{<:GenericAffExpr}) ||
                       isa(obj, AbstractArray{<:DecisionAffExpr})
                    # Update obj name to reflect stage and scenario
                    arrayname = if N > 2
                        arrayname = add_subscript(add_subscript(objkey, stage), i)
                    else
                        arrayname = add_subscript(objkey, i)
                    end
                    # Handle each individual constraint/expression in array
                    for con in obj
                        # Update constraint/expression name to reflect stage and scenario
                        if name(con) == ""
                            # Do not need update unnamed constraints
                            continue
                        end
                        splitname = split(name(con), "[")
                        conname = if N > 2
                            conname = add_subscript(splitname[1], stage)
                        else
                            conname = splitname[1]
                        end
                        set_name(con, @sprintf("%s[%s", add_subscript(conname,i), splitname[2]))
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
        end
        # Update objective
        set_objective_function(dep_model, dep_obj)
        set_objective_sense(dep_model, obj_sense)
    end
    return nothing
end

function clear!(dep::DeterministicEquivalent)
    # Clear decisions
    clear!(dep.decisions)
    # Clear deterministic equivalent model
    empty!(dep.model)
    return nothing
end
