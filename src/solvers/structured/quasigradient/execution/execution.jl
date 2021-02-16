abstract type AbstractQuasiGradientExecution end
# Execution API #
# ------------------------------------------------------------
initialize_subproblems!(quasigradient::AbstractQuasiGradient, scenarioproblems::AbstractScenarioProblems) = initialize_subproblems!(quasigradient.execution, scenarioproblems)
#restore_subproblems!(quasigradient::AbstractQuasiGradient) = restore_subproblems!(quasigradient, quasigradient.execution)
solve_master!(quasigradient::AbstractQuasiGradient) = solve_master!(quasigradient, quasigradient.execution)
iterate!(quasigradient::AbstractQuasiGradient) = iterate!(quasigradient, quasigradient.execution)
start_workers!(quasigradient::AbstractQuasiGradient) = start_workers!(quasigradient, quasigradient.execution)
close_workers!(quasigradient::AbstractQuasiGradient) = close_workers!(quasigradient, quasigradient.execution)
resolve_subproblems!(quasigradient::AbstractQuasiGradient) = resolve_subproblems!(quasigradient, quasigradient.execution)
current_decision(quasigradient::AbstractQuasiGradient) = current_decision(quasigradient, quasigradient.execution)
calculate_objective_value(quasigradient::AbstractQuasiGradient) = calculate_objective_value(quasigradient, quasigradient.execution)
timestamp(quasigradient::AbstractQuasiGradient) = timestamp(quasigradient, quasigradient.execution)
subobjectives(quasigradient::AbstractQuasiGradient) = subobjectives(quasigradient, quasigradient.execution)
set_subobjectives(quasigradient::AbstractQuasiGradient, Qs::AbstractVector) = set_subobjectives(quasigradient, Qs, quasigradient.execution)
# ------------------------------------------------------------
include("common.jl")
include("serial.jl")
include("distributed.jl")
include("synchronous.jl")
#include("asynchronous.jl")
