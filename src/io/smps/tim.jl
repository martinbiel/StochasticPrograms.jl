struct RawTime
    name::String
    stages::Dict{Period, Int}
    col_delims::Vector{Col}
    row_delims::Vector{Row}
end

function parse_tim(filename::String)
    # Initialize auxiliary variables
    name       = "SLP"
    mode       = :NAME
    stage      = 1
    stages     = Dict{Period, Int}()
    col_delims = Vector{Col}()
    row_delims = Vector{Row}()
    # Parse the file
    open(filename) do io
        firstline = split(readline(io))
        if Symbol(firstline[1]) == :TIME
            name = join(firstline[2:end], " ")
        else
            throw(ArgumentError("`TIME` field is expected on the first line."))
        end
        for line in eachline(io)
            if mode == END
                # Parse finished
                break
            end
            words = split(line)
            first_word = Symbol(words[1])
            if first_word in TIM_MODES
                mode = first_word
                continue
            end
            if mode == PERIODS
                push!(col_delims, Symbol(words[1]))
                push!(row_delims, Symbol(words[2]))
                stages[Symbol(words[3])] = stage
                stage += 1
            else
                throw(ArgumentError("$(mode) is not a valid tim file mode."))
            end
        end
    end
    # Return tim data
    return RawTime(name, stages, col_delims, row_delims)
end

num_stages(tim::RawTime) = length(tim.stages)
