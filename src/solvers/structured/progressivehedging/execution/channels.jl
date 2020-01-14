mutable struct IterationChannel{D} <: AbstractChannel{D}
    data::Dict{Int,D}
    cond_take::Condition
    IterationChannel(data::Dict{Int,D}) where D = new{D}(data, Condition())
end

function put!(channel::IterationChannel, t, x)
    channel.data[t] = copy(x)
    notify(channel.cond_take)
    return channel
end

function take!(channel::IterationChannel, t)
    x = fetch(channel, t)
    delete!(channel.data, t)
    return x
end

isready(channel::IterationChannel) = length(channel.data) > 1
isready(channel::IterationChannel, t) = haskey(channel.data, t)

function fetch(channel::IterationChannel, t)
    wait(channel, t)
    return channel.data[t]
end

function wait(channel::IterationChannel, t)
    while !isready(channel, t)
        wait(channel.cond_take)
    end
end

mutable struct RunningAverageChannel{D} <: AbstractChannel{D}
    average::D
    data::Vector{D}
    buffer::Dict{Int,D}
    cond_put::Condition
    RunningAverageChannel(average::D, data::Vector{D}) where D = new{D}(average, data, Dict{Int,D}(), Condition())
end

function take!(channel::RunningAverageChannel, i::Integer)
    channel.buffer[i] = copy(channel.data[i])
end

function put!(channel::RunningAverageChannel, i::Integer, π::AbstractFloat)
    channel.average -= π*channel.buffer[i]
    channel.average += π*channel.data[i]
    delete!(channel.buffer, i)
    notify(channel.cond_put)
    return channel
end

function put!(channel::RunningAverageChannel{D}, i::Integer, x::D, π::AbstractFloat) where D
    channel.average -= π*channel.buffer[i]
    channel.average += π*x
    channel.data[i] = copy(x)
    delete!(channel.buffer, i)
    notify(channel.cond_put)
    return channel
end

isready(channel::RunningAverageChannel) = length(channel.buffer) == 0

function fetch(channel::RunningAverageChannel)
    wait(channel)
    return channel.average
end

function fetch(channel::RunningAverageChannel, i::Integer)
    return channel.data[i]
end

function wait(channel::RunningAverageChannel)
    while !isready(channel)
        wait(channel.cond_put)
    end
end

IteratedValue{T <: AbstractFloat} = RemoteChannel{IterationChannel{T}}
RunningAverage{D} = RemoteChannel{RunningAverageChannel{D}}
Decisions{A <: AbstractArray} = RemoteChannel{IterationChannel{A}}
