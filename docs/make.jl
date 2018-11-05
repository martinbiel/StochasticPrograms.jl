using Documenter, StochasticPrograms

makedocs(sitename = "StochasticPrograms.jl",
         doctest = false,
         clean = false,
         pages = [
             "Home" => "index.md",
             hide("Manual" => "manual/quickstart.md", Any[
                 "Quick start" => "manual/quickstart.md",
                 "Stochastic data" => "manual/data.md",
                 "Model definition" => "manual/modeldef.md",
                 "Distributed stochastic programs" => "manual/distributed.md",
                 "Structured solvers" => "manual/structuredsolvers.md",
                 "Examples" => "manual/examples.md",
             ]),
             hide("LShapedSolvers.jl" => "lshaped/overview.md", Any[
                 "Overview" => "lshaped/overview.md",
             ]),
             hide("ProgressiveHedgingSolvers.jl" => "progressivehedging/overview.md", Any[
                 "Overview" => "progressivehedging/overview.md",
             ]),
             hide("Library" => "library/public.md", Any[
                 "Public interface" => "library/public.md",
                 "Solver interface" => "library/solverinterface.md"
             ])
         ])
