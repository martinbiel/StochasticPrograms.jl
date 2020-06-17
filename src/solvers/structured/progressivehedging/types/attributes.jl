# Attributes #
# ========================== #
abstract type AbstractProgressiveHedgingAttribute <: AbstractStructuredOptimizerAttribute end

struct PrimalTolerance <: AbstractProgressiveHedgingAttribute end

struct DualTolerance <: AbstractProgressiveHedgingAttribute end

struct Penalizer <: AbstractProgressiveHedgingAttribute end

struct Penaltyterm <: AbstractProgressiveHedgingAttribute end

abstract type PenalizationParameter <: AbstractProgressiveHedgingAttribute end
