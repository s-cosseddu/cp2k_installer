# Install CP2K in Cartesius using intel compilers, thanks andreas.gloess@chem.uzh.ch

function print_arch () {

cat <<"EOF"
# Pure MPI version for Intel Compilers on Bullx cluster (Cartesius, NL)
CC       = cc
CPP      = 
FC       = mpiifort 
LD       = mpiifort 
AR       = ar -r

CPPFLAGS =
DFLAGS   = -D__MKL -D__FFTW3 -D__parallel \
	    -D__SCALAPACK -D__LIBXC2 -D__LIBINT 
CFLAGS   = $(DFLAGS) 
FCFLAGS  = $(DFLAGS) -O2 -g -traceback -fpp -free \
           -I$(MKLROOT)/include -I$(MKLROOT)/include/fftw
FCFLAGS2 = $(DFLAGS) -O1 -g -traceback -fpp -free \
           -I$(MKLROOT)/include -I$(MKLROOT)/include/fftw
LDFLAGS  = $(FCFLAGS) -static-intel 
LIBS     = $(MKLROOT)/lib/intel64/libmkl_scalapack_lp64.a \
	  -Wl,--start-group  $(MKLROOT)/lib/intel64/libmkl_intel_lp64.a \
	   $(MKLROOT)/lib/intel64/libmkl_sequential.a \
	   $(MKLROOT)/lib/intel64/libmkl_core.a \
	   $(MKLROOT)/lib/intel64/libmkl_blacs_intelmpi_lp64.a -Wl,--end-group \
	   -lpthread -lm \
	   -lstdc++ \
	   -L/home/cosseddu/Programmi/CP2K/test_comp/cp2k/libint/libint-release-1-1-6/compiled/lib -lderiv -lint \
	    -L/home/cosseddu/Programmi/CP2K/test_comp/cp2k/libxc/libxc-2.2.2/compiled/lib -lxcf90 -lxc 
	       
mp2_optimize_ri_basis.o: mp2_optimize_ri_basis.F
			 $(FC) -c $(FCFLAGS2) $<

EOF


}

function writeslurm () {

    cat << EOF
#!/bin/bash
#
#SBATCH -N 1
#SBATCH --tasks-per-node $1
#SBATCH -t 1:00:00

module unload mkl mpi fortran c
module load mkl/11.2.2 mpi/impi/5.0.3.048 fortran/intel/15.0.0 c/intel/15.0.0 compilerwrappers

make -j $1 ARCH=cartesius VERSION=popt
EOF

}


ROOT=$PWD
CP2KDIR=${ROOT}/cp2k
NPROCS=8


# Download trunk version
if [ ! -d "cp2k" ]; then
   svn checkout http://svn.code.sf.net/p/cp2k/code/trunk cp2k
   cd $CP2KDIR
else 
   cd $CP2KDIR
   svn checkout http://svn.code.sf.net/p/cp2k/code/trunk/cp2k cp2k
fi 

# libint
mkdir libint
cd libint/
wget https://github.com/evaleev/libint/archive/release-1-1-6.tar.gz
tar xzf release-1-1-6.tar.gz 
cd libint-release-1-1-6/
aclocal -I lib/autoconf/
autoconf 
mkdir obj_compile
cd obj_compile
../configure --prefix=/home/cosseddu/Programmi/CP2K/test_comp/cp2k/libint/libint-release-1-1-6/compiled --enable-static CC='icc' CFLAGS='-O2' CXX='icpc' CXXFLAGS='-O2'
make -j $NPROCS
make install
cd $CP2KDIR
# -----


# libxc
mkdir libxc
cd libxc/
wget http://www.tddft.org/programs/octopus/download/libxc/libxc-2.2.2.tar.gz
tar xzf libxc-2.2.2.tar.gz 
cd libxc-2.2.2
mkdir obj_compile
cd obj_compile
pwd 
../configure --prefix=/home/cosseddu/Programmi/CP2K/test_comp/cp2k/libxc/libxc-2.2.2/compiled --enable-static CC=icc CFLAGS='-O2' FC='ifort' FCFLAGS='-O2'
make -j $NPROCS
make install
cd $CP2KDIR


# cp2k 
cd cp2k/makefiles/
print_arch > ../arch/cartesius.popt
make distclean
writeslurm $NPROCS > compile.slurm
sbatch compile.slurm

exit 0