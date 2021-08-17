# MIT License
#
# Copyright (c) 2018 Martin Biel
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

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
