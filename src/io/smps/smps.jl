module SMPS

# Standard library
using LinearAlgebra
using SparseArrays
using Distributed

# External libraries
using StochasticPrograms
using Distributions
using OrderedCollections

import Base: read

const Row = Symbol
const Col = Symbol
const Idx = Int
const IdxGroup = Tuple{Idx, Idx, Symbol}
const Period = Symbol
const RowCol = Tuple{Symbol, Symbol}
const RowColVal{T} = Tuple{Symbol, Symbol, T}

include("tim.jl")
include("cor.jl")
include("lp.jl")
include("sto.jl")
include("raw.jl")
include("stage.jl")
include("scenario.jl")
include("sampler.jl")
include("model.jl")
include("reader.jl")

end
