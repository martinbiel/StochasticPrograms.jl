"""
    StochasticModel

A mathematical model of a stochastic optimization problem.
"""
struct StochasticModel{D₁, D₂}
    first_stage::D₁
    second_stage::D₂
    generator::Function

    function (::Type{StochasticModel})(first_stage::D₁, second_stage::D₂, generator::Function) where {D₁, D₂}
        return new{D₁, D₂}(first_stage, second_stage, generator)
    end
end
StochasticModel(generator::Function) = StochasticModel(nothing, nothing, generator)

# Printing #
# ========================== #
function Base.show(io::IO, stochasticmodel::StochasticModel)

end
# ========================== #
