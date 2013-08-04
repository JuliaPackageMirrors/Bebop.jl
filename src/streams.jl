export Stream, openStream, closeStream, writeStream

const TypeToSampleFormat = {Float32 => 0x1, Int32 => 0x2, Int16 => 0x8, 
                            Int8 => 0x10, Uint8 => 0x20}

type Stream
    pastream::PaStream
    channels::Int32
    sampleRate::Float64
    framesPerBuffer::Uint
    dtype::DataType
end

function InputStreamParameters(device::Integer, numChannels::Integer, 
                               dtype::DataType)
    devinfo = DeviceInfo(device)
    return StreamParameters(convert(Int32, device), convert(Int32, numChannels), 
                            convert(Uint, TypeToSampleFormat[dtype]),
                            devinfo.defaultHighInputLatency, 
                            convert(Ptr{None}, C_NULL))
end

function OutputStreamParameters(device::Integer, numChannels::Integer, 
                                   dtype::DataType)
    devinfo = DeviceInfo(device)
    return StreamParameters(convert(Int32, device), 
                            convert(Int32, numChannels), 
                            convert(Uint, TypeToSampleFormat[dtype]),
                            devinfo.defaultHighOutputLatency, 
                            convert(Ptr{None}, C_NULL))
end


function openStream(inputId::Integer, outputId::Integer, 
                       sampleRate::FloatingPoint, numChannels::Integer, 
                       framesPerBuffer::Integer, dtype::DataType)
    pastream = Array(PaStream, 1)
    inputParams = InputStreamParameters(inputId, numChannels, dtype)
    outputParams = OutputStreamParameters(outputId, numChannels, dtype)

    err = ccall((:Pa_OpenStream, portaudio), Int32, 
                (Ptr{PaStream}, Ptr{StreamParameters}, Ptr{StreamParameters},
                 Float64, Uint, Uint, Ptr{Void}, Ptr{Void}),
                pastream, &inputParams, &outputParams, 
                sampleRate, framesPerBuffer, 0, C_NULL, C_NULL)
    check_pa_error(err)
    return Stream(pastream[], 
                  convert(Int32, numChannels), 
                  convert(Float64, sampleRate),
                  convert(Uint, framesPerBuffer),
                  dtype)
end

function openStream(sampleRate::FloatingPoint, numChannels::Integer, dtype::DataType)
    openStream(defaultInputDevice(), defaultOutputDevice(),
               sampleRate, numChannels, 1024, dtype)
end

function closeStream(stream::Stream)
    err = ccall((:Pa_CloseStream, portaudio), Int32, (PaStream,), stream.pastream)
    check_pa_error(err)
end

function withStream(f::Function, stream::Stream)
    err = ccall((:Pa_StartStream, portaudio), Int32, (PaStream,), stream.pastream)
    check_pa_error(err)
    f()
    err = ccall((:Pa_StopStream, portaudio), Int32, (PaStream,), stream.pastream)
    check_pa_error(err)
end

function writeStream{T}(stream::Stream, data::Vector{T})
    if stream.dtype != T
        error("Type mismatch: expected $(stream.dtype), got $T")
    end
    stride = stream.framesPerBuffer
    withStream(stream) do
        for i in 1:stride:endof(data)
            bufend = min(i + stride - 1,  endof(data))
            buffer = data[i:bufend]
            err = ccall((:Pa_WriteStream, portaudio), Int32, 
                        (PaStream, Ptr{Void}, Uint),
                        stream.pastream, buffer, length(buffer))
            check_pa_error(err)
        end
    end
end