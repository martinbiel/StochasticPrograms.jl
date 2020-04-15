function initialize!(stochasticprogram::StochasticProgram)
    initialize!(stochasticprogram, provided_optimizer(stochasticprogram))
end

function initialize!(stochasticprogram::StochasticProgram, ::UnrecognizedOptimizerProvided)
    # Error here if an unrecognized optimizer has been provided
    error("Trying to initialize stochasticprogram with unrecognized optimizer.")
end

function initialize!(stochasticprogram::StochasticProgram, ::NoOptimizerProvided)
    @warn "Cannot initialize without optimizer. Consider [`set_optimizer!`](@ref)."
    # Do not initialize anything if no optimizer is attached
    return
end

function initialize!(stochasticprogram::StochasticProgram, ::OptimizerProvided)
    # Check that all generators are there
    _check_generators(stochasticprogram)
    # If the attached optimizer is an MOI optimizer, generate
    # the deterministic equivalent problem
    # Return possibly cached model
    cache = problemcache(stochasticprogram)
    if haskey(cache, :dep)
        # Deterministic equivalent already generated
        stochasticprogram.optimizer.optimizer = backend(cache[:dep])
        return nothing
    end
    # Generate and cache deterministic equivalent
    cache[:dep] = generate_deterministic_equivalent(stochasticprogram)
    stochasticprogram.optimizer.optimizer = backend(cache[:dep])
    return nothing
end

function initialize!(stochasticprogram::StochasticProgram, ::StructuredOptimizerProvided)
    # Check that all generators are there
    _check_generators(stochasticprogram)
    # Generate block-structured stochastic program
    if deferred(stochasticprogram)
        generate!(stochasticprogram)
    end
    # Initialize optimizer
    stochasticprogram.optimizer.optimizer = MOI.instantiate(optimizer_constructor(stochasticprogram))
    return nothing
end

_check_generators(stochasticprogram::StochasticProgram{N}) where N = _check_generators(stochasticprogram, Val(N))
function _check_generators(stochasticprogram::StochasticProgram, ::Val{N}) where N
    return _check_stage_generator(stochasticprogram, N) && _check_generators(stochasticprogram, Val(N-1))
end
function _check_generators(stochasticprogram::StochasticProgram, ::Val{1})
    return has_generator(stochasticprogram, :stage_1)
end
function _check_stage_generator(stochasticprogram::StochasticProgram{N}, s::Integer) where N
    1 <= s <= N || error("Stage $s not in range 1 to $N.")
    stage_key = Symbol(:stage_, s)
    return has_generator(stochasticprogram, stage_key)
end
