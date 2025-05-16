#!/usr/bin/env bash

set -e

function install_linux_deps() {
  if [[ -x "$(command -v apt)" ]]; then
    # For Ubuntu (not applicable to RHEL, kept for completeness)
    sudo apt install -y wget curl ca-certificates gnupg2 \
      g++ gcc gfortran git make ccache libssl-dev zlib1g-dev zip unzip \
      clang-format clang-tidy lcov libtool m4 autoconf automake python3 python3-pip \
      pkg-config uuid-dev libaio-dev libopenblas-dev libgoogle-perftools-dev

    pip3 install conan==1.64.1

  elif [[ -x "$(command -v dnf)" ]]; then
    # For RHEL 9.5 s390x
    echo "Installing dependencies for RHEL 9.5 s390x..."
    sudo dnf install -y epel-release
    sudo dnf install -y wget curl git make gcc gcc-c++ gfortran \
      clang clang-tools-extra cmake \
      python3 python3-pip python3-devel \
      openblas-devel libaio libuuid-devel zip unzip \
      ccache lcov libtool m4 autoconf automake \
      zlib-devel libcurl-devel libnghttp2-devel \
      libevent-devel gflags-devel lz4-devel snappy-devel #zstd-devel

    pip3 install conan==2.16.1

  else
    echo "Unsupported package manager. Cannot install dependencies."
    exit 1
  fi

  # CMake installation (3.26.4 or newer) from source if necessary
  if ! command -v cmake >/dev/null || [[ "$(cmake --version | grep -oP '\d+\.\d+')" < "3.26" ]]; then
    echo "Installing CMake 3.26.4 from source..."
    CMAKE_VERSION=3.26.4
    wget https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}.tar.gz
    tar -xzf cmake-${CMAKE_VERSION}.tar.gz
    cd cmake-${CMAKE_VERSION}
    ./bootstrap
    make -j$(nproc)
    sudo make install
    cd ..
    rm -rf cmake-${CMAKE_VERSION}*
  fi

  echo "✅ All dependencies installed successfully."
}

install_linux_deps

