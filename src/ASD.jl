module ASD

using FileIO

function __init__()
    add_format(format"ASD", (), ".asd")
end

export ASDData, ASDHeader, load

struct ASDHeader
    fileVersion::Int32 #File version
    fileHeaderSize::Int32 #Size of the file header
    frameHeaderSize::Int32 #Size of the frame header
    encNumber::Int32 #Charachteristic number for encoding
    operationNameSize::Int32 #Size of the operation name
    commentSize::Int32 #Size of the comment
    dataTypeCh1::Int32 #Data type of 1ch (Topography, Error or Phase) written by enum array
    dataTypeCh2::Int32 #Data type of 2ch (Topography, Error or Phase) written by enum array
    numberFramesRecorded::Int32 #Number of frames when this asd file was originally recorded
    numberFramesCurrent::Int32 #Number of frames contained in the current asd file
    scanDirection::Int32 #Number showing scanning direction
    fileName::Int32 #Name of the asd file
    xPixel::Int32 #X pixel
    yPixel::Int32 #Y pixel
    xScanRange::Int32 #X scanning range in nm
    yScanRange::Int32 #Y scanning range in nm
    avgFlag::Bool #Flag of the averaging
    avgNumber::Int32 #Number of data for the averaging
    yearRec::Int32 #Year when this asd file was recorded
    monthRec::Int32 # Month when this asd file was recorded
    dayRec::Int32 #Day when this asd file was recorded
    hourRec::Int32 #Hour when this asd file was recorded
    minuteRec::Int32 #Minute when this asd file was recorded
    secondRec::Int32 #Second when this asd file was recorded
    xRoundDeg::Int32 # Degree of the rounding of x-scanning signal(%)
    yRoundDeg::Int32 #Degree of the rounding of y-scanning signal(%)
    frameAcqTime::Float32 #Frame acquisition time (ms)
    sensorSens::Float32 #Sensor sensitivity (nm/V)
    phaseSens::Float32 #Phase sensitivity (deg/V)
    offset::NTuple{4,Int32} #Offset 12 bytes
    machineNum::Int32 #Number of imaging machine
    adRange::Int32 #Code showing AD range (AD_1V,AD2P5V, AD_5V of AD_80V)
    adRes::Int32 #AD resolution (When this value is 12, the AD resolution is 4096(2^12))
    xMaxScanRange::Float32 #X maximum scanning range (nm)
    yMaxScanRange::Float32 #Y maximum scanning range (nm)
    xExtCoef::Float32 #X piezo extention coefficient (nm/V)
    yExtCoef::Float32 #Y piezo extention coefficient (nm/V)
    zExtCoef::Float32 #Z piezo extention coefficient (nm/V)
    zDriveGain::Float32 #Z piezo drive gain
    operName::String #Name of operator
    comment::String #Comment
end

struct ASDData
    header::ASDHeader
    data
end

function load(filename::File{format"ASD"})
    field_names = fieldnames(ASDHeader)
    types = fieldtypes(ASDHeader)
    val = Any[]
    open(filename) do io
        for (name, type) in zip(field_names, types)
            if type <: Number
                eval(Meta.parse("$(name)::$(type) = read(io,$(type))"))
                println("$(name)::$(type) = ", eval(name))
            elseif type <: NTuple
                N = length(type.parameters)
                T = type.parameters[1]
                eval(Meta.parse("$(name)::$(type) = ntuple(i -> read(io,$T),$N)"))
                println("$(name)::$(type) = ", eval(name))
            elseif name == :operName
                eval(Meta.parse("$(name)::$(type) = read(io,operationNameSize) |> String"))
                println("$(name)::$(type) = ", eval(name))
            elseif name == :comment
                eval(Meta.parse("$(name)::$(type) = read(io,commentSize) |> String"))
                println("$(name)::$(type) = ", eval(name))
            else
                error("Unkonwn error")
            end
            push!(val, eval(name))
        end
    end
    return ASDHeader(val...)
end

load(filename::String) = load(query(filename))


end # module ASD