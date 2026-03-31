FROM ubuntu:24.04 AS build

WORKDIR /app

RUN apt-get update && \
    apt-get install -y build-essential wget cmake git libcurl4-openssl-dev \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

COPY . .

ENV CFLAGS="-march=goldmont-plus"
ENV CXXFLAGS="-march=goldmont-plus"
RUN cmake -B build \
    -DGGML_AVX=OFF \
    -DGGML_AVX2=OFF \
    -DGGML_FMA=OFF \
    -DGGML_F16C=OFF \
    -DGGML_BMI2=OFF \
    -DGGML_NATIVE=OFF \
    -DCMAKE_C_FLAGS="-march=goldmont-plus" \
    -DCMAKE_CXX_FLAGS="-march=goldmont-plus" \
    -DCMAKE_BUILD_TYPE=Release && \
    cmake --build build -j$(nproc)

FROM ubuntu:24.04 AS runtime

WORKDIR /app

RUN apt-get update && \
    apt-get install -y curl ffmpeg wget \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

COPY --from=build /app/build/bin/ /usr/local/bin/
COPY --from=build /app/build/src/libwhisper.so* /usr/local/lib/
COPY --from=build /app/build/ggml/src/libggml*.so* /usr/local/lib/
RUN ldconfig

COPY --from=build /app/models/download-ggml-model.sh /app/models/

ENV WHISPER_MODEL=tiny
ENV WHISPER_THREADS=4

EXPOSE 8080

ENTRYPOINT [ "bash", "-c" ]
CMD ["/app/models/download-ggml-model.sh ${WHISPER_MODEL} /models && whisper-server --model /models/ggml-${WHISPER_MODEL}.bin --host 0.0.0.0 --port 8080 --inference-path /v1/audio/transcriptions --threads ${WHISPER_THREADS} --processors 1 --convert --no-gpu -nfa"]
