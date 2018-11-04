using Documenter, StochasticPrograms

makedocs(sitename = "StochasticPrograms.jl",
         doctest = false,
         clean = false,
         pages = [
             "Home" => "index.md",
             "Manual" => Any[
                 "Quick start" => "manual/quickstart.md",
                 "Scenarios" => "manual/scenarios.md",
                 "Model definition" => "manual/modeldef.md",
                 "Distributed stochastic programs" => "manual/distributed.md",
                 "Structured solvers" => "manual/structuredsolvers.md",
                 "Examples" => "manual/examples.md",
             ],
             "LShapedSolvers.jl" => Any[
                 "Overview" => "lshaped/overview.md",
             ],
             "ProgressiveHedgingSolvers.jl" => Any[
                 "Overview" => "progressivehedging/overview.md",
             ],
             "Library" => Any[
                 "Public interface" => "library/public.md",
                 "Solver interface" => "library/solverinterface.md"
             ]
         ])
