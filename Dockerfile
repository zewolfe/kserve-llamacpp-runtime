ARG CUDA_VERSION=12.4.1

# Base Image
FROM nvidia/cuda:$CUDA_VERSION-devel-ubuntu22.04 AS builder-default

ARG LLAMA_CPP_SHA=812602fa101e798e2c59c8648ef67424606be711

RUN apt-get update \
  && apt-get install --no-install-recommends -y \
  build-essential \
  cmake \
  git \
  && apt autoremove -y \
  && apt clean -y \
  && rm -rf /tmp/* /var/tmp/* \
  && find /var/cache/apt/archives /var/lib/apt/lists -not -name lock -type f -delete \
  && find /var/cache -type f -delete

RUN git clone https://github.com/zewolfe/llama.cpp.git /src/llama.cpp
RUN cd /src/llama.cpp && git checkout $LLAMA_CPP_SHA 

RUN ln -sf /usr/local/cuda/lib64/stubs/libcuda.so /usr/local/cuda/lib64/stubs/libcuda.so.1 \
 && echo "/usr/local/cuda/lib64/stubs" > /etc/ld.so.conf.d/z-cuda-stubs.conf \
 && ldconfig

RUN cmake -S /src/llama.cpp -B /build \
  -DGGML_CUDA=ON \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_CUDA_ARCHITECTURES="89" \
  -DGGML_NATIVE=OFF \
  -DLLAMA_BUILD_SERVER=ON

RUN cmake --build /build --target llama-server -j 4


#  Builder Pooled
FROM builder-default AS builder-pooled

RUN cp /build/bin/llama-server /build/bin/llama-server-pooled

# Runtime

ARG CUDA_VERSION=12.4.1
FROM nvidia/cuda:$CUDA_VERSION-runtime-ubuntu22.04 AS runtime

ARG LLAMA_CPP_SHA=812602fa101e798e2c59c8648ef67424606be711
 
LABEL llamacpp.sha=$LLAMA_CPP_SHA
LABEL llamacpp.pooled.sha=""

COPY --from=builder-default /build/bin/ /usr/local/bin/
COPY --from=builder-default /build/bin/llama-server /usr/local/bin/llama-server
COPY --from=builder-pooled /build/bin/llama-server-pooled /usr/local/bin/llama-server-pooled

COPY entrypoint.sh /usr/local/bin/entrypoint.sh

ENV LD_LIBRARY_PATH=/usr/local/bin:${LD_LIBRARY_PATH}

RUN chmod +x /usr/local/bin/entrypoint.sh

RUN apt-get update \
 && apt-get install -y --no-install-recommends libgomp1 \
 && rm -rf /var/lib/apt/lists/*

USER 1000:1000

ENV ANANSI_LOADER=default \
  ANANSI_LOADER_ARGS="" \
  LLAMA_PORT=8080

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

