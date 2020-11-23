module SMPS

# Standard library
using LinearAlgebra
using Random
using SparseArrays
using Distributed

# External libraries
using StochasticPrograms
using Distributions
using Distributions: AliasTable
using OrderedCollections

import Base: read

# Common constants
const Row = Symbol
const Col = Symbol
const Idx = Int
const IdxGroup = Tuple{Idx, Idx, Symbol}
const InclusionType = Symbol
const DistributionType = Symbol
const Period = Symbol
const Block = Symbol
const RowCol = Tuple{Symbol, Symbol}
const RowColVal{T} = Tuple{Symbol, Symbol, T}

const OBJ = :OBJ
const LEQ = :LEQ
const EQ = :EQ
const GEQ = :GEQ
const RANGE = :RANGE
const LOWER = :LOWER
const UPPER = :UPPER
const FREE = :FREE
const FIXED = :FIXED

const NAME = :NAME
const END = :ENDATA

# TIM file constants
const PERIODS = :PERIODS
const TIM_MODES = [PERIODS, END]

# COR file constants
const ROWS = :ROWS
const COLUMNS = :COLUMNS
const RHS = :RHS
const RANGES = :RANGES
const BOUNDS = :BOUNDS
const COR_MODES = [NAME, ROWS, COLUMNS, RHS, RANGES, BOUNDS, END]

# STO file constants
const INDEP = :INDEP
const BLOCKS = :BLOCKS
const STO_MODES = [INDEP, BLOCKS, END]

const REPLACE = :REPLACE
const ADD = :ADD
const MULTIPLY = :MULTIPLY
const INCLUSIONS = [REPLACE, ADD, MULTIPLY]

const DISCRETE = :DISCRETE
const UNIFORM = :UNIFORM
const NORMAL = :NORMAL
const GAMMA = :GAMMA
const BETA = :BETA
const LOGNORM = :LOGNORM
const DISTRIBUTIONS = [DISCRETE, UNIFORM, NORMAL, GAMMA, BETA, LOGNORM]

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
