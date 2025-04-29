module TimedCollections

export TimedCollection, traverse_files!, traverse_file!

using DataStructures
using Dates

struct TimedCollection{T}
    dict::SortedDict{DateTime,T}
    TimedCollection{T}() where T = new(SortedDict{DateTime,T}())
end

function Base.push!(coll::TimedCollection, hd)
    push!(coll.dict, getproperty(hd, :timestamp) => hd)
end

Base.length(hc::TimedCollection) = length(hc.dict)
function Base.show(io::IO, hc::TimedCollection{T}) where T
    ioc = IOContext(stdout, :module=>parentmodule(T))
    for h in values(hc.dict)
        show(ioc, h)
        println(io)
    end
end

_convert(::Type{DateTime}, x) = DateTime(x)

Base.getindex(hc::TimedCollection, x::Any) = getindex(hc.dict, _convert(DateTime, x))
Base.get(hc::TimedCollection, x, d) = get(hc, _convert(DateTime, x), d)

function traverse_files!(coll, dir, r::Regex)
    files = readdir(dir)
    for file in files
        if match(r, file) !== nothing
            traverse_file!(coll, joinpath(dir, file))
        end
    end
    coll
end

function traverse_file! end

end # module
