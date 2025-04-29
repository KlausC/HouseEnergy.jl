
module FEMS

using CurlHTTP: CurlHTTP, CurlEasy, curl_execute
using JSON: JSON, Parser
using Dates
using Serialization
using DataStructures
using ..TimedCollections
import ..TimedCollections: traverse_file!

mutable struct StateData
    State::Int # Zustand des Systems / (0: Ok, 1:Info, 2:Warning, 3:Fault)
    EssSoc::Int # Ladezustand des Speichers / Prozent [%]
    EssActivePower::Float32 # [W]
    EssReactivePower::Float32 # [W]
    GridActivePower::Float32
    GridMinActivePower::Float32
    GridMaxActivePower::Float32
    ProductionActivePower::Float32
    ProductionMaxActivePower::Float32
    # ProductionAcActivePower::Float32
    ProductionDcActualPower::Float32
    ConsumptionActivePower::Float32
    ConsumptionMaxActivePower::Float32
    EssActiveChargeEnergy::Float64 # Energie Speicherbeladung / WattHours [Wh]
    EssActiveDischargeEnergy::Float64 # Energie Speicherentladung / WattHours [Wh]
    GridBuyActiveEnergy::Float64 # Energie Netzbezug / WattHours [Wh]
    GridSellActiveEnergy::Float64 # Energie Netzeinspeisung / WattHours [Wh]
    ProductionActiveEnergy::Float64 # Energie Erzeugung / WattHours [Wh]
    # ProductionAcActiveEnergy::Float64 # Energie AC Erzeugung / WattHours [Wh]
    ProductionDcActiveEnergy::Float64 # Energie DC Erzeugung / WattHours [Wh]
    ConsumptionActiveEnergy::Float64 # Energie Verbraucher / WattHours [Wh]
    EssDischargePower::Float32
    GridMode::Int
    StateData() = new(zeros(length(StateData.types))...)
end

function urlstring(ip, name)
    string("http://x:user@", ip, ":80/rest/channel/_sum/", name)
end

function readdata(ip, name)
    readurl(urlstring(ip, name))
end

function readurl(url)
    curl = CurlEasy(; url, method=CurlHTTP.GET, verbose=false)
    res, http_status, errormessage = curl_execute(curl)
    if !(res == 0 && http_status == 200)
        throw(ErrorException("res=$res http_status=$http_status $errormessage"))
    end
    v = Parser.parse(String(curl.userdata[:databuffer]))
    v["value"]
end

function readdata(ip)
    st = StateData()
    for name in propertynames(st)
        v = readdata(ip, name)
        setproperty!(st, name, something(v, 0))
    end
    st
end

function hysteresis(x::Bool, a::Real, b::Real, ip, name=:EssSoc)
    c = readdata(ip, name)
    (c >= a && x) || c >= b
end

function receive_fems_power(hours::Real=1.0)
    sts = []
    ip = "192.168.178.28"
    itime = Int(floor(hours * 3600)) ÷ 60
    ms0(x) = millisecond(x) == 0
    sec0(x) = second(x) == 0
    nextfullsecond = tonext(ms0, now(), step=Millisecond(1), limit=1000)
    nextfullminute = tonext(sec0, nextfullsecond, step=Second(1), limit=60)
    lastfullminute = nextfullminute + Minute(itime)
    filename = string("fems_", nextfullminute, "_", itime, ".ser")
    println("FEMS data will be written to $filename at $lastfullminute.")
    try
        for t = nextfullminute:Minute(1):lastfullminute
            sleep((t - now()).value / 1000)
            stp = FEMS.readdata(ip, "ConsumptionActivePower")
            ste = FEMS.readdata(ip, "ConsumptionActiveEnergy")
            ddd = (t, stp, ste)
            push!(sts, ddd)
            println(ddd)
        end
    catch
        ;
    end
    serialize(filename, sts)
    sts
end

const FEMS_DIR = joinpath(homedir(), "Dokumente", "Energie", "FEMS", "received")
const FEMS_REG = r"fems.*[.]ser"

struct FEMSData
    timestamp::DateTime
    power::Float64
    energy::Float64
end

function read_fems_files(;dir=FEMS_DIR, r::Regex=FEMS_REG)
    traverse_files!(TimedCollection{FEMSData}(), dir, r)
end

function traverse_file!(coll::TimedCollection{FEMSData}, file::AbstractString)
    sts = deserialize(file)
    for st in sts
        hd = FEMSData(st[1], st[2], st[3])
        push!(coll, hd)
    end
    nothing
end

end # module
