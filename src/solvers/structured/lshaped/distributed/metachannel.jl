mutable struct MetaChannel <: AbstractChannel
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
