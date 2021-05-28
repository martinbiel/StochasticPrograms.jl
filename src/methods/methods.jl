include("api.jl")
include("common.jl")
include("generation.jl")
include("evaluation.jl")
include("spconstructs.jl")
# structures
include("deterministic_equivalent/generation.jl")
include("deterministic_equivalent/evaluation.jl")
include("deterministic_equivalent/optimization.jl")
include("deterministic_equivalent/spconstructs.jl")

include("stage_decomposition/generation.jl")
include("stage_decomposition/evaluation.jl")
include("stage_decomposition/optimization.jl")
include("stage_decomposition/spconstructs.jl")

include("scenario_decomposition/generation.jl")
include("scenario_decomposition/evaluation.jl")
include("scenario_decomposition/optimization.jl")
include("scenario_decomposition/spconstructs.jl")

include("util.jl")
