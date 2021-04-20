abstract type AbstractProgressiveHedgingExecution end
# Execution API #
# ------------------------------------------------------------
initialize_subproblems!(ph::AbstractProgressiveHedging, scenarioproblems::AbstractScenarioProblems, penaltyterm::AbstractPenaltyTerm) = initialize_subproblems!(ph, ph.execution, scenarioproblems, penaltyterm)
finish_initilization!(ph::AbstractProgressiveHedging, penalty::AbstractFloat) = finish_initilization!(ph.execution, penalty)
restore_subproblems!(ph::AbstractProgressiveHedging) = restore_subproblems!(ph, ph.execution)
iterate!(ph::AbstractProgressiveHedging) = iterate!(ph, ph.execution)
start_workers!(ph::AbstractProgressiveHedging) = start_workers!(ph, ph.execution)
close_workers!(ph::AbstractProgressiveHedging) = close_workers!(ph, ph.execution)
resolve_subproblems!(ph::AbstractProgressiveHedging) = resolve_subproblems!(ph, ph.execution)
update_iterate!(ph::AbstractProgressiveHedging) = update_iterate!(ph, ph.execution)
update_subproblems!(ph::AbstractProgressiveHedging) = update_subproblems!(ph, ph.execution)
update_dual_gap!(ph::AbstractProgressiveHedging) = update_dual_gap!(ph, ph.execution)
calculate_objective_value(ph::AbstractProgressiveHedging) = calculate_objective_value(ph, ph.execution)
scalar_subproblem_reduction(value::Function, ph::AbstractProgressiveHedging) = scalar_subproblem_reduction(value, ph.execution)
vector_subproblem_reduction(value::Function, ph::AbstractProgressiveHedging, n::Integer) = scalar_subproblem_reduction(value, ph.execution, n)
# ------------------------------------------------------------
include("common.jl")
include("serial.jl")
include("channels.jl")
include("distributed.jl")
include("synchronous.jl")
include("asynchronous.jl")
