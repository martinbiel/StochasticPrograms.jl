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

include("vertical/generation.jl")
include("vertical/evaluation.jl")
include("vertical/optimization.jl")
include("vertical/spconstructs.jl")

include("horizontal/generation.jl")
include("horizontal/evaluation.jl")
include("horizontal/optimization.jl")
include("horizontal/spconstructs.jl")

include("util.jl")
