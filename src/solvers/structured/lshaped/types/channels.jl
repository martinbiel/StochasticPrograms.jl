mutable struct DecisionChannel{A <: AbstractArray} <: AbstractChannel{A}
    decisions::Dict{Int,A}
    cond_take::Condition
    DecisionChannel(decisions::Dict{Int,A}) where A <: AbstractArray = new{A}(decisions, Condition())
end

function put!(channel::DecisionChannel, t, x)
    channel.decisions[t] = copy(x)
    notify(channel.cond_take)
    return channel
end

function take!(channel::DecisionChannel, t)
    x = fetch(channel, t)
    delete!(channel.decisions, t)
    return x
end

isready(channel::DecisionChannel) = length(channel.decisions) > 1
isready(channel::DecisionChannel, t) = haskey(channel.decisions, t)

function fetch(channel::DecisionChannel, t)
    wait(channel, t)
    return channel.decisions[t]
end

function wait(channel::DecisionChannel, t)
    while !isready(channel, t)
        wait(channel.cond_take)
    end
end

Decisions{A} = RemoteChannel{DecisionChannel{A}}

mutable struct MetaChannel <: AbstractChannel{Any}
    metadata::Dict{Tuple{Int,Symbol},Any}
    cond_take::Condition
    MetaChannel() = new(Dict{Tuple{Int,Symbol},Any}(), Condition())
end

function put!(channel::MetaChannel, t, key, x)
    channel.metadata[(t,key)] = copy(x)
    notify(channel.cond_take)
    return channel
end

function take!(channel::MetaChannel, t, key)
    x = fetch(channel, t, key)
    delete!(channel.metadata, (t,k))
    return x
end

isready(channel::MetaChannel) = length(channel.metadata) > 1
isready(channel::MetaChannel, t, key) = haskey(channel.metadata, (t,key))

function fetch(channel::MetaChannel, t, key)
    wait(channel, t, key)
    return channel.metadata[(t,key)]
end

function wait(channel::MetaChannel, t, key)
    while !isready(channel, t, key)
        wait(channel.cond_take)
    end
end

MetaData = RemoteChannel{MetaChannel}
