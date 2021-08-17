# MIT License
#
# Copyright (c) 2018 Martin Biel
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

mutable struct IterateChannel{A <: AbstractArray} <: AbstractChannel{A}
    decisions::Dict{Int,A}
    cond_take::Condition
    IterateChannel(decisions::Dict{Int,A}) where A <: AbstractArray = new{A}(decisions, Condition())
end

function put!(channel::IterateChannel, t, x)
    channel.decisions[t] = copy(x)
    notify(channel.cond_take)
    return channel
end

function take!(channel::IterateChannel, t)
    x = fetch(channel, t)
    delete!(channel.decisions, t)
    return x
end

isready(channel::IterateChannel) = length(channel.decisions) > 1
isready(channel::IterateChannel, t) = haskey(channel.decisions, t)

function fetch(channel::IterateChannel, t)
    wait(channel, t)
    return channel.decisions[t]
end

function wait(channel::IterateChannel, t)
    while !isready(channel, t)
        wait(channel.cond_take)
    end
end

RemoteIterates{A} = RemoteChannel{IterateChannel{A}}

const MetaData = Dict{Tuple{Int,Symbol},Any}

has_metadata(data::MetaData, type::Symbol) = haskey(data, (0, type))
has_metadata(data::MetaData, idx::Integer, type::Symbol) = haskey(data, (idx, type))
get_metadata(data::MetaData, type::Symbol) = data[(0, type)]
get_metadata(data::MetaData, idx::Integer, type::Symbol) = data[(idx, type)]
function set_metadata!(data::MetaData, type::Symbol, value)
    data[(0, type)] = value
    return nothing
end
function set_metadata!(data::MetaData, idx::Integer, type::Symbol, value)
    data[(idx, type)] = value
    return nothing
end

mutable struct MetaChannel <: AbstractChannel{Any}
    metadata::MetaData
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

MetaDataChannel = RemoteChannel{MetaChannel}

has_metadata(data::MetaDataChannel, type::Symbol) = isready(data, 0, type)
has_metadata(data::MetaDataChannel, idx::Integer, type::Symbol) = isready(data, idx, type)
get_metadata(data::MetaDataChannel, type::Symbol) = fetch(data, 0, type)
get_metadata(data::MetaDataChannel, idx::Integer, type::Symbol) = fetch(data, idx, type)
function set_metadata!(data::MetaDataChannel, type::Symbol, value)
    put!(data, 0, type, value)
    return nothing
end
function set_metadata!(data::MetaDataChannel, idx::Integer, type::Symbol, value)
    put!(data, idx, type, value)
    return nothing
end
