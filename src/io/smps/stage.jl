struct SMPSStage{T <: AbstractFloat, M <: AbstractMatrix}
    id::Int
    model::LPData{T,M}
    uncertain::LPData{T,M}
    technology::UnitRange{Int}
    recourse::UnitRange{Int}

    function SMPSStage(model::LPData{T,M}) where {T <: AbstractFloat, M <: AbstractMatrix}
        return new{T, M}(1, model, LPData(T,M,0,0,0), 0:0, 0:0)
    end

    function SMPSStage(id::Integer, model::LPData{T,M}, uncertain::LPData{T,M}, technology::UnitRange{Int}, recourse::UnitRange{Int}) where {T <: AbstractFloat, M <: AbstractMatrix}
        return new{T, M}(id, model, uncertain, technology, recourse)
    end
end
