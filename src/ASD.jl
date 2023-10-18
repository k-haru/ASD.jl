module ASD

using FileIO, Unitful

function __init__()
    add_format(format"ASD", (), ".asd")
end

export ASDData, ASDHeader, load

const unipolar_1_0V = 0x00000001
const unipolar_2_5V = 0x00000002
const unipolar_5_0V = 0x00000004
const bipolar_1_0V = 0x00010000
const bipolar_2_5V = 0x00020000
const bipolar_5_0V = 0x00040000

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
    offset::NTuple{4,Int32} #Offset 4 bytes
    machineNum::Int32 #Number of imaging machine
    adRange::Tuple{Float32,Float32} #Code showing AD range (AD_1V,AD2P5V, AD_5V of AD_80V)
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
    Topography::Array{Float32,3}
    xOffset::Vector{Float32}
    yOffset::Vector{Float32}
    xTilt::Vector{Float32}
    yTilt::Vector{Float32}
end

struct ASDFile
    header::ASDHeader
    data::ASDData
end

function load_header(filename::File{format"ASD"})
    field_names = fieldnames(ASDHeader)
    types = fieldtypes(ASDHeader)
    vals = Any[]
    open(filename) do io
        for (name, type) in zip(field_names, types)
            if name == :fileVersion
                val = read(io, Int32)
                if val != 1
                    error("Unknown file version")
                end
            elseif name == :operName
                val = read(io, operationNameSize) |> String
            elseif name == :comment
                val = read(io, commentSize) |> String
            elseif name == :adRange
                val = read(io, Int32)
                if val == unipolar_1_0V
                    val = (0, 1)
                elseif val == unipolar_2_5V
                    val = (0, 2.5)
                elseif val == unipolar_5_0V
                    val = (0, 5)
                elseif val == bipolar_1_0V
                    val = (-1, 1)
                elseif val == bipolar_2_5V
                    val = (-2.5, 2.5)
                elseif val == bipolar_5_0V
                    val = (-5, 5)
                else
                    error("Unknown AD range")
                end
            elseif type <: NTuple
                N = length(type.parameters)
                T = type.parameters[1]
                val = ntuple(i -> read(io, T), N)
            elseif type <: Number
                val = read(io, type)
                "$name::$type = $val" |> Meta.parse |> eval
            else
                error("Unkonwn error")
            end
            println("$(name)::$(type) = ", val)
            push!(vals, val)
        end
    end
    ASDHeader(vals...)
end

function load_data(filename::File{format"ASD"}, header::ASDHeader)
    frameNumber = Vector{Int32}(undef, header.numberFramesCurrent)
    frameMaxData = Vector{UInt16}(undef, header.numberFramesCurrent)
    frameMinData = Vector{UInt16}(undef, header.numberFramesCurrent)
    xOffset = Vector{UInt16}(undef, header.numberFramesCurrent)
    yOffset = Vector{UInt16}(undef, header.numberFramesCurrent)
    xTilt = Vector{Float32}(undef, header.numberFramesCurrent)
    yTilt = Vector{Float32}(undef, header.numberFramesCurrent)
    flagLaserIr = Vector{Bool}(undef, header.numberFramesCurrent * 12)
    rawData = Array{UInt16}(undef, header.xPixel, header.yPixel, header.numberFramesCurrent)
    open(filename) do io
        seek(io, header.fileHeaderSize)
        frameSize = header.xPixel * header.yPixel
        for i in 1:header.numberFramesCurrent
            frameNumber[i] = read(io, Int32)
            frameMaxData[i] = read(io, UInt16)
            frameMinData[i] = read(io, UInt16)
            xOffset[i] = read(io, UInt16)
            yOffset[i] = read(io, UInt16)
            xTilt[i] = read(io, Float32)
            yTilt[i] = read(io, Float32)
            flagLaserIr[(i-1)*12+1:i*12] .= ntuple(i -> read(io, Bool), 12)
            rawData[(i-1)*frameSize+1:i*frameSize] .= ntuple(i -> read(io, UInt16), frameSize)
        end
    end
    rawData = permutedims(Float32.(rawData), (2, 1, 3))
    coef = header.zDriveGain * header.zExtCoef
    minrange, maxrange = header.adRange
    absvol = (maxrange - minrange)
    Topography = -((rawData ./ 2^header.adRes .* absvol) .+ minrange) * coef
    ASDData(Topography, xOffset, yOffset, xTilt, yTilt)
end

function load(filename::File{format"ASD"})
    header = load_header(filename)
    data = load_data(filename, header)
    ASDFile(header, data)
end

load(filename::String) = load(query(filename))


end # module ASD