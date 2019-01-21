"""
    StochasticModel

A mathematical model of a stochastic optimization problem.
"""
struct StochasticModel{D₁, D₂}
    first_stage::Stage{D₁}
    second_stage::Stage{D₂}
    generator::Function

    function (::Type{StochasticModel})(first_stage::D₁, second_stage::D₂, generator::Function) where {D₁, D₂}
        return new{D₁, D₂}(Stage(1, first_stage), Stage(2, second_stage), generator)
    end

    function (::Type{StochasticModel})(::Nothing, ::Nothing, generator::Function)
        return new{Any, Any}(Stage(1, nothing), Stage(2, nothing), generator)
    end
end
StochasticModel(generator::Function) = StochasticModel(nothing, nothing, generator)

# Printing #
# ========================== #
function Base.show(io::IO, stochasticmodel::StochasticModel)
    modelstr = "minimize cᵀx + 𝔼[Q(x,ξ)]
  x∈ℝⁿ  Ax = b
         x ≥ 0

where

Q(x,ξ) = min  q(ξ)ᵀy
        y∈ℝᵐ T(ξ)x + Wy = h(ξ)
              y ≥ 0"
    print(io, "Stochastic Model\n\n")
    println(io, modelstr)
end
# ========================== #
