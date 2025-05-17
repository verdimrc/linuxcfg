FROM nvcr.io/nvidia/nemo:25.04

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends ripgrep tree time dstat

ENV PYTHONPATH=/opt/NeMo:$PYTHONPATH
