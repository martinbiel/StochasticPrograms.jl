# Attributes #
# ========================== #
abstract type AbstractProgressiveHedgingAttribute <: AbstractStructuredOptimizerAttribute end

struct Penalizer <: AbstractProgressiveHedgingAttribute end

struct Penaltyterm <: AbstractProgressiveHedgingAttribute end

abstract type PenalizationParameter <: AbstractProgressiveHedgingAttribute end
