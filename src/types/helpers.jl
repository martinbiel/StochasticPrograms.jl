struct AdditiveZeroArray{T,N} <: AbstractArray{T,N} end

Base.:(+)(lhs::AbstractArray{T,N}, rhs::AdditiveZeroArray{T,N}) where {T,N} = lhs
Base.:(+)(lhs::AdditiveZeroArray{T,N}, rhs::AbstractArray{T,N}) where {T,N} = rhs
Base.:(-)(lhs::AbstractArray{T,N}, rhs::AdditiveZeroArray{T,N}) where {T,N} = lhs
Base.:(-)(lhs::AdditiveZeroArray{T,N}, rhs::AbstractArray{T,N}) where {T,N} = -rhs
Base.:(*)(lhs::Number, rhs::AdditiveZeroArray{T,N}) where {T,N} = rhs
Base.:(*)(lhs::AdditiveZeroArray{T,N}, rhs::Number) where {T,N} = lhs
