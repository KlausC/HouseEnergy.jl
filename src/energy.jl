module Energy

using CSV
using Parsers
using Dates
using ..TimedCollections
import ..TimedCollections: traverse_file!

import Base: push!

const F = Float64
const HEAT_DIR = joinpath(homedir(), "Buderus", "Verbrauch")
const HEAT_REG = r"^Energy.*[.]csv$"

mutable struct HeatData
    category::String
    timestamp::DateTime
    heatPumpOutputProducedTotal::F
    #heatPumpOutputProducedCh
    #heatPumpOutputProducedDhw
    environmentTotal::F
    #environmentCh
    #environmentDhw
    boilerOutputProducedTotal::F
    #boilerOutputProducedCh
    #boilerOutputProducedDhw
    burnerGasTotal::F
    #burnerGasCh
    #burnerGasDhw
    electricityTotal::F
    #electricityCh
    #electricityDhw
    compressorTotal::F
    #compressorCh
    #compressorDhw
    outdoorTemperature::F
    flowTemperature::F
    hotWaterTemperature::F
    HeatData() = new()
end

timestamp(h::HeatData) = h.timestamp

function read_heat_files(; dir=HEAT_DIR, r::Regex=HEAT_REG)
    traverse_files!(TimedCollection{HeatData}(), dir, r)
end

function traverse_file!(coll::TimedCollection{HeatData}, file::AbstractString)
    df = Dates.DateFormat("y-m-dTH:M:S")
    ty = [String; DateTime; fill(String, 23)]
    cmd = `sed -e '1 s/1/;/' $file`
    options = Parsers.Options(decimal=',')
    tab = CSV.Rows(cmd; header=1, types=ty, normalizenames=true, silencewarnings=true, missingstring=["", "-"],
        delim=';', dateformat=df, decimal=',')
    for t in tab
        hd = HeatData()
        stop = false
        for key in fieldnames(HeatData)
            field = getproperty(t, key)
            stop |= key == :outdoorTemperature && ismissing(field)
            T = fieldtype(HeatData, key)
            if T <: Real
                field isa String && (field = Parsers.tryparse(T, field, options))
                field isa Real || (field = zero(T))
            end
            setproperty!(hd, key, field)
        end
        hd.category != "hour" && continue
        stop && break
        push!(coll, hd)
    end
    nothing
end

"""
    spreader(z::Real, y::itr)

Produce an output-vector `x` with `∑x_i == z` and `x_i <= y_i ∀ i` with minimal variance.
Assume `y_i >= 0` and `∑y_i >= z`.
"""
spreader(z, y) = spreader!(z, y ./ 1)
function spreader!(z::Real, y::AbstractVector{<:Real})
    n = length(y)
    T = typeof(one(eltype(y)) / n)
    x = y
    ip = sortperm(y)
    z = max(T(z), zero(T))
    for i = 1:n
        m = n + 1 - i
        xx = z / m
        yi = y[ip[i]]
        if yi >= xx
            x[ip[i:n]] .= xx
            break
        else
            xi = max(yi, zero(T))
            z -= xi
            x[ip[i]] = xi
        end
    end
    x
end

end # module
