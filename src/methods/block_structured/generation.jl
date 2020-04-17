function generate!(stochasticprogram::StochasticProgram{N}, structure::AbstractBlockStructure{N}) where N
    # Generate all stages
    for stage in 1:N
        generate!(stochasticprogram, structure, stage)
    end
    return nothing
end

function clear(structure::AbstractBlockStructure{N}) where N
    # Clear all stages
    for stage in 1:N
        clear_stage!(stochasticprogram, structure, stage)
    end
    return nothing
end
