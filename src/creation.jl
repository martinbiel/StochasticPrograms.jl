# Creation macros #
# ========================== #
macro first_stage(args)
    @capture(args, model_Symbol = modeldef_) || error("Invalid syntax. Expected stochasticprogram = begin JuMPdef end")
    vardefs = Expr(:block)
    for line in modeldef.args
        (@capture(line, @constraint(m_Symbol,constdef__)) || @capture(line, @objective(m_Symbol,objdef__))) && continue
        push!(vardefs.args,line)
    end
    code = @q begin
        $(esc(model)).ext[:SP].generator[:first_stage_vars] = ($(esc(:model))::JuMP.Model,$(esc(:commondata))) -> begin
            $(esc(vardefs))
	    return $(esc(:model))
        end
        $(esc(model)).ext[:SP].generator[:first_stage] = ($(esc(:model))::JuMP.Model,$(esc(:commondata))) -> begin
            $(esc(modeldef))
	    return $(esc(:model))
        end
        generate_stage_one!($(esc(model)))
    end
    return code
end

macro second_stage(args)
    @capture(args, model_Symbol = modeldef_) || error("Invalid syntax. Expected stochasticprogram = begin JuMPdef end")
    def = postwalk(modeldef) do x
        @capture(x, @decision args__) || return x
        code = Expr(:block)
        for var in args
            varkey = Meta.quot(var)
            push!(code.args,:($var = parent.objDict[$varkey]))
        end
        return code
    end

    code = @q begin
        $(esc(model)).ext[:SP].generator[:second_stage] = ($(esc(:model))::JuMP.Model,$(esc(:commondata)),$(esc(:scenario))::AbstractScenarioData,$(esc(:parent))::JuMP.Model) -> begin
            $(esc(def))
	    return $(esc(:model))
        end
        generate_stage_two!($(esc(model)))
        nothing
    end
    return prettify(code)
end
# ========================== #
