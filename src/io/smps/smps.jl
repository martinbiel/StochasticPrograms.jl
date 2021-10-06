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

@reexport module SMPS

# Standard library
using LinearAlgebra
using Random
using SparseArrays
using Distributed

# External libraries
using StochasticPrograms
using StochasticPrograms: canonical
using Compat
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
const BINARY = :BINARY
const INTEGER = :INTEGER
const INTEGER_LOWER = :INTEGER_LOWER
const INTEGER_UPPER = :INTEGER_UPPER
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
const SCENARIOS = :SCENARIOS
const STO_MODES = [INDEP, BLOCKS, SCENARIOS, END]

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

export
    SMPSScenario,
    SMPSSampler

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
