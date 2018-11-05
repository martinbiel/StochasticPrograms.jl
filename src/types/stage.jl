mutable struct Stage{D}
    stage::Int
    data::D

    function (::Type{Stage})(stage::Integer, data::D) where D
        return new{D}(stage, data)
    end

    function (::Type{Stage})(stage::Integer, ::Nothing)
        return new{Any}(stage, nothing)
    end
end
stagetype(stage::Stage{D}) where D = D
