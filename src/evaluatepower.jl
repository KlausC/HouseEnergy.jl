module EvaluatePower

export evaluate_power, plot_power

using Dates
using ..TimedCollections
using ..Energy
using ..FEMS
using CairoMakie

const MIN_PER_HOUR = 60
const F = Float64

function evaluate_power(time::DateTime, hours::Integer=1)
    fems = FEMS.read_fems_files()
    heat = Energy.read_heat_files()
    fd = F[]
    hd = F[]
    toutd = F[]
    tflow = F[]
    thotw = F[]

    for i = 1:hours
        f, h, t1, t2, t3 = evaluate_power(fems, heat, time)
        append!(fd, f)
        append!(hd, h)
        append!(toutd, t1)
        append!(tflow, t2)
        append!(thotw, t3)
        time += Hour(1)
    end
    fd, hd, toutd, tflow, thotw
end

function evaluate_power(fems, heat::TimedCollection{Energy.HeatData}, time::DateTime)
    spreader = Energy.spreader
    hd = heat[time]
    times = [time + Minute(m) for m in 0:MIN_PER_HOUR]

    en = getindex.(Ref(fems), times)
    fd = diff([e.energy * (MIN_PER_HOUR / 1000) for e in en]) # Wh => kWh * min / h

    z1 = hd.compressorTotal * MIN_PER_HOUR # kWh => kWh * min / h
    # hd1 = spreader(z1, fd)
    z2 = sum(fd) - z1
    hd2 = fd .- spreader(z2, fd)

    toptemp = fill(100.0, MIN_PER_HOUR)
    toutd = hd.outdoorTemperature
    tflow = hd.flowTemperature
    thotw = hd.hotWaterTemperature

    fd, hd2, toutd, tflow, thotw
end

function plot_power(time, hours::Integer=1)
    fd, hd, toutd, tflow, thotw = evaluate_power(time, hours)
    n = length(fd)
    title = string(Dates.format(time, "yyyy-mm-dd HH:MM"), " $(hours*MIN_PER_HOUR) Minutes")
    xticks = 0:15:n
    yticks = 0:0.5:7
    xlabel = "Minutes"
    ylabel = "kW"
    #guidefont = (11, :black)
    taxis = 0:n-1

    f = Figure(; size=(1900, 600))
    ax = Axis(f[1, 1]; title, xlabel, ylabel, xticks, yticks)
    lines!(ax, taxis, fd)
    lines!(ax, taxis, hd)
    # lines!(ax, taxis, fd .- hd)

    blowup(a) = vcat(fill.(a, 60)...)

    axt = Axis(f[2, 1]; ylabel="°C", xlabel, xticks, yticks=-10:1:40)
    lines!(axt, taxis, blowup(toutd); label="außen")
    lines!(axt, taxis, blowup(tflow .- 20); label="vorlauf-20")
    #lines!(axt, taxis, blowup(thotw .- 40); label="heißwasser-40")

    axislegend(axt, "Temperatur"; position=:rt)
    display(f)
    save("plot_$(time)_$(hours).svg", f)
    f
end

end # EvaluatePower
