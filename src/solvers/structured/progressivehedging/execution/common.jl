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

function iterate!(ph::AbstractProgressiveHedging, ::AbstractProgressiveHedgingExecution)
    # Resolve all subproblems at the current optimal solution
    Q = resolve_subproblems!(ph)
    if !(Q.status ∈ AcceptableTermination)
        # Early termination log
        log!(ph; status = Q.status)
        return Q.status
    end
    ph.data.Q = Q.value
    # Update iterate
    update_iterate!(ph)
    # Update subproblems
    update_subproblems!(ph)
    # Get dual gap
    update_dual_gap!(ph)
    # Update penalty (if applicable)
    update_penalty!(ph)
    # Check optimality
    if check_optimality(ph)
        # Final log
        log!(ph; optimal = true)
        # Optimal
        return MOI.OPTIMAL
    end
    # Calculate time spent so far and check perform time limit check
    time_spent = ph.progress.tlast - ph.progress.tinit
    if time_spent >= ph.parameters.time_limit
        log!(ph; status = MOI.TIME_LIMIT)
        return MOI.TIME_LIMIT
    end
    # Log progress
    log!(ph)
    # Dont return a status as procedure should continue
    return nothing
end

function finish_initilization!(execution::AbstractProgressiveHedgingExecution, penalty::AbstractFloat)
    @sync begin
        for w in workers()
            @async remotecall_fetch(
                w,
                execution.subworkers[w-1],
                penalty) do sw, penalty
                    for subproblem in fetch(sw)
                        initialize!(subproblem, penalty)
                    end
                end
        end
    end
    return nothing
end

function start_workers!(::AbstractProgressiveHedging, ::AbstractProgressiveHedgingExecution)
    return nothing
end

function close_workers!(::AbstractProgressiveHedging, ::AbstractProgressiveHedgingExecution)
    return nothing
end
