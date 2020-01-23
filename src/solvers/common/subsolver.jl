SubSolver = Union{MPB.AbstractMathProgSolver, Function}
QPSolver = Union{MPB.AbstractMathProgSolver, Function}
get_solver(subsolver::MPB.AbstractMathProgSolver) = subsolver
get_solver(generator::Function)::MPB.AbstractMathProgSolver = generator()
