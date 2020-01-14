niters() = niters(30)
function niters(niters)
    return (τ,n) -> begin
        return n >= niters
    end
end

tolerance_reached() = at_tolerance(1e-3)
function tolerance_reached(tol)
    return (τ,n) -> begin
        return τ <= tol
    end
end
