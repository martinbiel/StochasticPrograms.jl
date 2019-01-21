using Documenter, StochasticPrograms

makedocs(sitename = "StochasticPrograms.jl",
         clean = false,
         pages = [
             "Home" => "index.md",
             "Manual" => Any[
                 "Quick start" => "manual/quickstart.md",
                 "Stochastic data" => "manual/data.md",
                 "Stochastic models" => "manual/modeldef.md",
                 "Distributed stochastic programs" => "manual/distributed.md",
                 "Structured solvers" => "manual/structuredsolvers.md",
                 "Examples" => "manual/examples.md",
             ],
             "Library" =>  Any[
                 "Public interface" => "library/public.md",
                 "Solver interface" => "library/solverinterface.md"
             ]
         ])

deploydocs(
    repo = "github.com/martinbiel/StochasticPrograms.jl.git",
)
