#!/usr/bin/env bash

# Exit on any error
set -e

# Skip if explicitly requested
if [[ ${SKIP_3RDPARTY} -eq 1 ]]; then
  echo "Skipping third-party build as requested."
  exit 0
fi

# Resolve this script's real path (in case of symlinks)
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done

# Directories
ROOT_DIR="$( cd -P "$( dirname "$SOURCE" )/.." && pwd )"
CPP_SRC_DIR="${ROOT_DIR}/internal/core"
BUILD_OUTPUT_DIR="${ROOT_DIR}/cmake_build"

# Create build output directory if needed
mkdir -p ${BUILD_OUTPUT_DIR}

# Source environment setup if applicable
source ${ROOT_DIR}/scripts/setenv.sh

pushd ${BUILD_OUTPUT_DIR}

# Ensure Conan 2 is being used
REQUIRED_CONAN_MAJOR=2
CONAN_MAJOR_VERSION=$(conan --version | awk '{print $3}' | cut -d. -f1)
if [[ "$CONAN_MAJOR_VERSION" -lt "$REQUIRED_CONAN_MAJOR" ]]; then
    echo "ERROR: Conan 2.x required. Current version: $(conan --version)"
    exit 1
fi

# Force detection of a default Conan profile
conan profile detect --force

# Compiler flags
export CONAN_REVISIONS_ENABLED=1
export CXXFLAGS="-Wno-error=address -Wno-error=deprecated-declarations"
export CFLAGS="-Wno-error=address -Wno-error=deprecated-declarations"

# Conan install per OS
unameOut="$(uname -s)"
case "${unameOut}" in
  Darwin*)
    conan install ${CPP_SRC_DIR} \
      --output-folder=conan \
      --build=missing \
      -s compiler=clang \
      -s compiler.version=${llvm_version} \
      -s compiler.libcxx=libc++ \
      -s compiler.cppstd=17 \
      --remote=none || { echo 'conan install failed'; exit 1; }
    ;;
  Linux*)
    if [ -f /etc/os-release ]; then
        OS_NAME=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d '=' -f2 | tr -d '"')
    else
        OS_NAME="Linux"
    fi
    echo "Running on ${OS_NAME}"
    export CPU_TARGET=avx
    GCC_VERSION=$(gcc -dumpversion)
    LIBSTDCXX_ABI=$(gcc -v 2>&1 | sed -n 's/.*\(--with-default-libstdcxx-abi\)=\(\w*\).*/\2/p')
    if [[ "${LIBSTDCXX_ABI}" == "gcc4" ]]; then
      conan install ${CPP_SRC_DIR} \
        --output-folder=conan \
        --build=missing \
        -s compiler=gcc \
        -s compiler.version=${GCC_VERSION} \
        --remote=none || { echo 'conan install failed'; exit 1; }
    else
      conan install ${CPP_SRC_DIR} \
        --output-folder=conan \
        --build=missing \
        -s compiler=gcc \
        -s compiler.version=${GCC_VERSION} \
        -s compiler.libcxx=libstdc++11 \
        --remote=none || { echo 'conan install failed'; exit 1; }
    fi
    ;;
  *)
    echo "Cannot build on this OS: ${unameOut}"
    exit 1
    ;;
esac

popd

# Create expected output dirs
mkdir -p ${ROOT_DIR}/internal/core/output/lib
mkdir -p ${ROOT_DIR}/internal/core/output/include

# Rust setup for dependencies
pushd ${ROOT_DIR}/cmake_build/thirdparty
if command -v cargo >/dev/null 2>&1; then
    echo "cargo exists"
    case "$(uname -s)" in
        Darwin*)
            echo "running on macOS, reinstall rust 1.83"
            rustup install 1.83
            rustup default 1.83
            ;;
        *)
            echo "not running on macOS, no need to reinstall rust"
            ;;
    esac
else
    echo "cargo not found, installing rust 1.83"
    curl https://sh.rustup.rs -sSf | sh -s -- --default-toolchain=1.83 -y || { echo 'rustup install failed'; exit 1; }
    source $HOME/.cargo/env
fi
popd

