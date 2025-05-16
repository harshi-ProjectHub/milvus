#!/usr/bin/env bash

# Modified build-3rdparty.sh for s390x support on RHEL 9.5

# Skip if user explicitly opts out
if [[ ${SKIP_3RDPARTY} -eq 1 ]]; then
  exit 0
fi

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done

BUILD_OPENDAL="OFF"
while getopts "o:" arg; do
  case $arg in
    o) BUILD_OPENDAL=$OPTARG ;;
  esac
done

ROOT_DIR="$( cd -P "$( dirname "$SOURCE" )/.." && pwd )"
CPP_SRC_DIR="${ROOT_DIR}/internal/core"
BUILD_OUTPUT_DIR="${ROOT_DIR}/cmake_build"

mkdir -p "${BUILD_OUTPUT_DIR}"

source ${ROOT_DIR}/scripts/setenv.sh
pushd "${BUILD_OUTPUT_DIR}"

export CONAN_REVISIONS_ENABLED=1
export CXXFLAGS="-Wno-error=address -Wno-error=deprecated-declarations"
export CFLAGS="-Wno-error=address -Wno-error=deprecated-declarations"

CONAN_ARTIFACTORY_URL="${CONAN_ARTIFACTORY_URL:-https://milvus01.jfrog.io/artifactory/api/conan/default-conan-local}"

if [[ ! $(conan remote list) == *default-conan-local* ]]; then
  conan remote add default-conan-local "${CONAN_ARTIFACTORY_URL}"
fi

if [ -f /etc/os-release ]; then
  OS_NAME=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d '=' -f2 | tr -d '"')
else
  OS_NAME="Linux"
fi

echo "Running on ${OS_NAME}"
export CPU_TARGET=native

# Ensure profile is correctly set for s390x
conan profile new default --detect --force
conan profile update settings.arch=s390x default
conan profile update settings.arch_build=s390x default
conan profile update settings.compiler=gcc default
conan profile update settings.compiler.version=12 default
conan profile update settings.compiler.libcxx=libstdc++11 default
conan profile update settings.build_type=Release default


GCC_VERSION=$(gcc -dumpversion)

# Force building everything from source
conan install "${CPP_SRC_DIR}" --install-folder conan \
  --build=cmake \
  --build=rocksdb \
  --build=missing \
  -s arch=s390x \
  -s arch_build=s390x \
  -s compiler.version=12 \
  -s compiler.libcxx=libstdc++11 \
  -s compiler=gcc \
  -s os=Linux \
  -s build_type=Release \
  -r default-conan-local \
  -u || { echo 'conan install failed'; exit 1; }

popd

mkdir -p "${ROOT_DIR}/internal/core/output/lib"
mkdir -p "${ROOT_DIR}/internal/core/output/include"

pushd "${ROOT_DIR}/cmake_build/thirdparty"

# Rust is needed for simde, opentelemetry and others
if command -v cargo >/dev/null 2>&1; then
  echo "cargo exists"
else
  bash -c "curl https://sh.rustup.rs -sSf | sh -s -- --default-toolchain=1.83 -y" || {
    echo 'rustup install failed'
    exit 1
  }
  source "$HOME/.cargo/env"
fi

popd

