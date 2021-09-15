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

function timestamp(quasigradient::AbstractQuasiGradient, ::AbstractQuasiGradientExecution)
    return quasigradient.data.iterations
end

function current_decision(quasigradient::AbstractQuasiGradient, ::AbstractQuasiGradientExecution)
    return quasigradient.x
end

function start_workers!(::AbstractQuasiGradient, ::AbstractQuasiGradientExecution)
    return nothing
end

function close_workers!(::AbstractQuasiGradient, ::AbstractQuasiGradientExecution)
    return nothing
end

function subobjectives(quasigradient::AbstractQuasiGradient, execution::AbstractQuasiGradientExecution)
    return execution.subobjectives
end

function set_subobjectives(quasigradient::AbstractQuasiGradient, Qs::AbstractVector, execution::AbstractQuasiGradientExecution)
    execution.subobjectives .= Qs
    return nothing
end

function solve_master!(quasigradient::AbstractQuasiGradient, ::AbstractQuasiGradientExecution)
    try
        MOI.optimize!(quasigradient.master)
    catch err
        status = MOI.get(quasigradient.master, MOI.TerminationStatus())
        # Master problem could not be solved for some reason.
        @unpack Q,θ = quasigradient.data
        gap = abs(θ-Q)/(abs(Q)+1e-10)
        # Always print this warning
        @warn "Master problem could not be solved, solver returned status $status. The following relative tolerance was reached: $(@sprintf("%.1e",gap)). Aborting procedure."
        rethrow(err)
    end
    return MOI.get(quasigradient.master, MOI.TerminationStatus())
end

function iterate!(quasigradient::AbstractQuasiGradient, execution::AbstractQuasiGradientExecution)
    # Resolve all subproblems at the current optimal solution
    Q = resolve_subproblems!(quasigradient)
    if Q == Inf
        # Early termination log
        log!(quasigradient; status = MOI.INFEASIBLE)
        return MOI.INFEASIBLE
    end
    if Q == -Inf
        # Early termination log
        log!(quasigradient; status = MOI.DUAL_INFEASIBLE)
        return MOI.DUAL_INFEASIBLE
    end
    sense = MOI.get(quasigradient.master, MOI.ObjectiveSense())
    coeff = sense == MOI.MIN_SENSE ? 1.0 : -1.0
    if coeff*Q <= coeff*quasigradient.data.Q
        quasigradient.data.Q = Q
        quasigradient.ξ .= quasigradient.x
    end
    # Determine stepsize
    γ = step(quasigradient,
             quasigradient.data.iterations,
             Q,
             quasigradient.x,
             quasigradient.gradient)
    # Proximal subgradient update
    prox!(quasigradient,
          quasigradient.x,
          quasigradient.gradient,
          γ)
    # Log progress
    log!(quasigradient)
    # Check optimality
    if terminate(quasigradient,
                 quasigradient.data.iterations,
                 Q,
                 quasigradient.x,
                 quasigradient.gradient)
        # Optimal, final log
        log!(quasigradient; optimal = true)
        return MOI.OPTIMAL
    end
    # Calculate time spent so far and check perform time limit check
    time_spent = quasigradient.progress.tlast - quasigradient.progress.tinit
    if time_spent >= quasigradient.parameters.time_limit
        log!(quasigradient; status = MOI.TIME_LIMIT)
        return MOI.TIME_LIMIT
    end
    # Dont return a status as procedure should continue
    return nothing
end
