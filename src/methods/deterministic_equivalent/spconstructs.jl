function DEP(stochasticprogram::StochasticProgram{2}, dep::DeterministicEquivalent; optimizer = nothing)
    # Ensure stochastic program has been generated at this point
    if deferred(stochasticprogram)
        generate!(stochasticprogram)
    end
    if optimizer == nothing
        return dep.model
    end
    dep_model = copy(dep.model)
    set_optimizer(dep_model, optimizer)
    return dep_model
end
