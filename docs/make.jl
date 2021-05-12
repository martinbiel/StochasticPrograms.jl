using Documenter, StochasticPrograms

makedocs(sitename = "StochasticPrograms.jl",
         clean = false,
         pages = [
             "Home" => "index.md",
             "Manual" => Any[
                 "Quick start" => "manual/quickstart.md",
                 "Stochastic data" => "manual/data.md",
                 "Stochastic models" => "manual/model.md",
                 "Multi-stage decisions" => "manual/decisions.md",
                 "Distributed stochastic programs" => "manual/distributed.md",
                 "Structured solvers" => "manual/structuredsolvers.md",
                 "Examples" => "manual/examples.md",
             ],
             "Library" =>  Any[
                 "Public interface" => "library/public.md",
                 "Solver interface" => "library/solverinterface.md",
                 "Crash" => "library/crash.md",
                 "L-shaped solvers" => "library/lshaped.md",
                 "Progressive-hedging solvers" => "library/progressivehedging.md",
                 "Quasi-gradient solvers" => "library/quasigradient.md"
             ]
         ])

deploydocs(
    repo = "github.com/martinbiel/StochasticPrograms.jl.git",
)
