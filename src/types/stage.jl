mutable struct Stage{D}
    stage::Int
    data::D

    function (::Type{Stage})(stage::Integer,data::D) where D
        return new{D}(stage,data)
    end
end
