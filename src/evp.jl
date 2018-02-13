function EVP(model::JuMP.Model; solver::MathProgBase.AbstractMathProgSolver = JuMP.UnsetSolver())
    haskey(model.ext,:SP) || error("The given model is not a stochastic program.")

    ev_model = extract_firststage(model)
    generator(model)(ev_model,expected(scenarios(model)))
    take_ownership!(ev_model)
    setsolver(ev_model,solver)

    solve(ev_model)

    return ev_model
end
