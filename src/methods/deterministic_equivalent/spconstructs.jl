# Deterministic equivalent spconstructs #
# ===================================== #
function DEP(stochasticprogram::StochasticProgram{2}, structure::DeterministicEquivalent; optimizer = nothing)
    # Ensure stochastic program has been generated at this point
    if deferred(stochasticprogram)
        generate!(stochasticprogram)
    end
    if optimizer == nothing
        return structure.model
    end
    structure_model = copy(structure.model)
    set_optimizer(structure_model, optimizer)
    return structure_model
end
