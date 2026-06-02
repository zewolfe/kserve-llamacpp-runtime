ARG CUDA_VERSION=12.9.2

# Base Image
FROM nvidia/cuda:$CUDA_VERSION-devel-ubuntu24.04 AS builder-default

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

RUN git clone https://github.com/ggml-org/llama.cpp.git /src/llama.cpp
RUN cd /src/llama.cpp && git checkout $LLAMA_CPP_SHA 


RUN cmake -S /src/llama.cpp -B /build \
  -DGGML_CUDA=ON \
  -DCMAKE_BUILD_TYPE=Release \
  -DC_MAKE_CUDA_ARCHITECTURES="86;89" \
  -DGGML_NATIVE=OFF \
  -DLLAMA_BUILD_SERVER=ON

RUN cmake --build /build --target llama-server -j 4


#  Builder Pipelined
FROM builder-default AS builder-pipelined

ARG LLAMA_CPP_SHA=5254a7994d1c3b651878efd5b18b1d647a91b1f2

LABEL org.opencontainers.image.source=""
LABEL org.opencontainers.image.revision=""
LABEL org.opencontainers.image.version="dev"
LABEL llamacpp.sha=$LLAMA_CPP_SHA
LABEL llamacpp.pipelined.sha=""

RUN cp /build/bin/llama-server /build/bin/llama-server-pipelined

# Runtime

ARG CUDA_VERSION=12.9.2
FROM nvidia/cuda:$CUDA_VERSION-runtime-ubuntu24.04

COPY --from=builder-default /build/bin/llama-server /usr/local/bin/llama-server
COPY --from=builder-pipelined /build/bin/llama-server-pipelined /usr/local/bin/llama-server-pipelined

COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN useradd -u 1000 -g 1000 -m llama-user
USER 1000:1000

ENV ANANSI_LOADER=default \
  ANANSI_LOADER_ARGS="" \
  LLAMA_PORT=8080

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

