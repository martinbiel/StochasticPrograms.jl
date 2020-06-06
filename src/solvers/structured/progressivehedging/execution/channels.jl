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

mutable struct RunningAverage{D}
    average::D
    data::Vector{D}
    buffer::Dict{Int,D}

    RunningAverage(average::D, data::Vector{D}) where D = new{D}(average, data, Dict{Int,D}())
end

function average(running_average::RunningAverage)
    return running_average.average
end

function subtract!(running_average::RunningAverage, i::Integer)
    running_average.buffer[i] = copy(running_average.data[i])
end

function add!(running_average::RunningAverage, i::Integer, π::AbstractFloat)
    running_average.average -= π * running_average.buffer[i]
    running_average.average += π * running_average.data[i]
    return running_average
end

function add!(running_average::RunningAverage{D}, i::Integer, x::D, π::AbstractFloat) where D
    running_average.average -= π * running_average.buffer[i]
    running_average.average += π * x
    running_average.data[i] = copy(x)
    return running_average
end

IteratedValue{T <: AbstractFloat} = RemoteChannel{IterationChannel{T}}
RemoteRunningAverage{D} = RemoteChannel{Channel{RunningAverage{D}}}
RemoteIterates{A <: AbstractArray} = RemoteChannel{IterationChannel{A}}
