# Attributes #
# ========================== #
abstract type AbstractLShapedAttribute <: AbstractStructuredOptimizerAttribute end

struct FeasibilityCuts <: AbstractLShapedAttribute end

struct Regularizer <: AbstractLShapedAttribute end

struct Aggregator <: AbstractLShapedAttribute end

struct Consolidator <: AbstractLShapedAttribute end

abstract type RegularizationParameter <: AbstractLShapedAttribute end

abstract type AggregationParameter <: AbstractLShapedAttribute end

abstract type ConsolidationParameter <: AbstractLShapedAttribute end
