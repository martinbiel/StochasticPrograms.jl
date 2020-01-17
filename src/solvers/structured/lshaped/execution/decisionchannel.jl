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
