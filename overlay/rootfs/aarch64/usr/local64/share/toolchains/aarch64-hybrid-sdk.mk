CC=			/toolchain/bin/clang
XCC=			/toolchain/bin/clang
CPP=			/toolchain/bin/clang-cpp
XCPP=			/toolchain/bin/clang-cpp
CXX=			/toolchain/bin/clang++
XCXX=			/toolchain/bin/clang++
CROSS_BINUTILS_PREFIX=	/toolchain/bin/
X_COMPILER_TYPE=	clang

CROSS_HOST=		aarch64-unknown-freebsd14.0

# /toolchain/bin/wrapper requires MACHINE_ARCH_HYBRID to be defined to configure
# the toolchain to cross-compile for the hybrid ABI.
MACHINE_ARCH_HYBRID=	1
.export MACHINE_ARCH_HYBRID
