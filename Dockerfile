ARG BASE_IMAGE=debian:buster-slim
FROM ${BASE_IMAGE}

# Fix DL4006
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# ---- Miniforge installer ----
# Default values can be overridden at build time
# Check https://github.com/conda-forge/miniforge/releases
# Conda version
ARG CONDA_VERSION="4.9.2"
# Miniforge installer patch version
ARG MINIFORGE_PATCH_NUMBER="7"
# Package Manager and Python implementation to use (https://github.com/conda-forge/miniforge)
# - conda only: either Miniforge3 to use Python or Miniforge-pypy3 to use PyPy
# - conda + mamba: either Mambaforge to use Python or Mambaforge-pypy3 to use PyPy
ARG MINIFORGE_PYTHON="Mambaforge"

# Miniforge archive to install
ARG MINIFORGE_VERSION="${CONDA_VERSION}-${MINIFORGE_PATCH_NUMBER}"
# Miniforge installer
ARG MINIFORGE_INSTALLER="${MINIFORGE_PYTHON}-${MINIFORGE_VERSION}-Linux-x86_64.sh"
# Miniforge checksum
ARG MINIFORGE_CHECKSUM="5a827a62d98ba2217796a9dc7673380257ed7c161017565fba8ce785fb21a599"

# Python version. Default value is the same as miniforge default version
ARG PYTHON_VERSION=default
# Force debian to accept default values for commands
ARG DEBIAN_FRONTEND=noninteractive

# Install basics
RUN set -xe && \
    apt-get -q update && \
    apt-get install -yq --no-install-recommends \
        wget \
        ca-certificates \
        locales \
        fonts-liberation && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN set -xe && \
    # Force locale to en-US
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen && \
    # Enable prompt color in the skeleton .bashrc before creating the non-root users
    # hadolint ignore=SC2016
    sed -i 's/^#force_color_prompt=yes/force_color_prompt=yes/' /etc/skel/.bashrc && \
    # Add call to conda init script see https://stackoverflow.com/a/58081608/4413446
    echo 'eval "$(command conda shell.bash hook 2> /dev/null)"' | tee -a ~/.bashrc >> /etc/skel/.bashrc

# Install miniforge
# Prerequisites installation: conda, mamba, pip, tini
ENV CONDA_DIR=/opt/conda
ENV PATH=$CONDA_DIR/bin:$PATH

RUN set -xe && \
    wget --quiet "https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VERSION}/${MINIFORGE_INSTALLER}" && \
    echo "${MINIFORGE_CHECKSUM} *${MINIFORGE_INSTALLER}" | sha256sum --check && \
    /bin/bash "${MINIFORGE_INSTALLER}" -f -b -p $CONDA_DIR && \
    rm "${MINIFORGE_INSTALLER}" && \
    # Conda configuration see https://conda.io/projects/conda/en/latest/configuration.html
    echo "conda ${CONDA_VERSION}" >> $CONDA_DIR/conda-meta/pinned && \
    conda config --system --set auto_update_conda false && \
    conda config --system --set show_channel_urls true && \
    if [ ! $PYTHON_VERSION = 'default' ]; then \
        conda install --yes python=$PYTHON_VERSION; \
    fi && \
    # Pin python version only to update only maintenance releases
    conda list python | grep '^python ' | tr -s ' ' | cut -d '.' -f 1,2 | sed 's/$/.*/' >> $CONDA_DIR/conda-meta/pinned && \
    conda install --quiet --yes \
        conda=${CONDA_VERSION} \
        pip \
        tini=0.18.0 && \
    conda update --all --quiet --yes && \
    conda list tini | grep tini | tr -s ' ' | cut -d ' ' -f 1,2 >> $CONDA_DIR/conda-meta/pinned && \
    conda clean --all -f -y

# Configure container startup
ENTRYPOINT ["tini", "-g", "--"]
