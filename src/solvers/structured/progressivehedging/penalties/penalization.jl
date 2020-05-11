abstract type AbstractPenalization end
abstract type AbstractPenalizer end
# Penalization API #
# ------------------------------------------------------------
penalty(ph::AbstractProgressiveHedging) = penalty(ph, ph.penalization)
initialize_penalty!(ph::AbstractProgressiveHedging) = initialize_penalty!(ph, ph.penalization)
update_penalty!(ph::AbstractProgressiveHedging) = update_penalty!(ph, ph.penalization)
# ------------------------------------------------------------
include("fixed.jl")
include("adaptive.jl")
