abstract type AbstractPenalization end
abstract type AbstractPenalizer end
# Penalization API #
# ------------------------------------------------------------
penalty(ph::AbstractProgressiveHedgingSolver) = penalty(ph, ph.penalization)
init_penalty!(ph::AbstractProgressiveHedgingSolver) = init_penalty!(ph, ph.penalization)
update_penalty!(ph::AbstractProgressiveHedgingSolver) = update_penalty!(ph, ph.penalization)
# ------------------------------------------------------------
include("fixed.jl")
include("adaptive.jl")
