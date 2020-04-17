DMATRICES = X Z Lambdatx Lambdati Lambdatp
FMATRICES = Whalf WX Wy ZtW XtWX XtWy ZtWX ZtWy L Lambdat-new L-new cu RZX DD deviance

DMATRICES_R  = $(addsuffix -r.bin,  $(DMATRICES))
DMATRICES_PY = $(addsuffix -py.bin, $(DMATRICES))

FMATRICES_R  = $(addsuffix -r.bin,  $(FMATRICES))
FMATRICES_PY = $(addsuffix -py.bin, $(FMATRICES))


# we can get -0 vs +0, so binary comparison won't work here
define cmp
echo 'Comparing $1 in Python and R...'
python3 cmp.py -a $1-py.bin -b $1-r.bin

endef

check: check_design check_fit

check_fit: lme4pureR $(FMATRICES_R) $(FMATRICES_PY) rand.bin
	$(foreach mat,$(FMATRICES),$(call cmp,$(mat)))

$(FMATRICES_PY): data.feather formula.txt rand.bin
	echo 'Generating fitting matrices in Python...'
	python3 run_pls.py --formula formula.txt --data data.feather \
		--randomdata rand.bin

$(FMATRICES_R): data.feather formula.txt rand.bin
	echo 'Generating fitting matrices in R...'
	Rscript run_pls.r --formula formula.txt --data data.feather \
		--randomdata rand.bin

.PHONY: lme4pureR
lme4pureR:
	echo 'Reinstalling lme4pureR...'
	R CMD INSTALL --no-help --no-byte-compile --no-test-load $@ 2> /dev/null

check_design: $(DMATRICES_PY) $(DMATRICES_R)
	$(foreach mat,$(DMATRICES),$(call cmp,$(mat)))

$(DMATRICES_R): data.feather formula.txt
	echo 'Generating design matrices in R...'
	Rscript build_matrices.r --data data.feather --formula formula.txt \
		$(foreach m,$(DMATRICES),--$m $m-r.bin)

$(DMATRICES_PY): data.feather formula.txt
	echo 'Generating design matrices in Python...'
	python3 build_matrices.py --data data.feather --formula formula.txt \
		$(foreach m,$(DMATRICES),--$m $m-py.bin)

# generate a pool of random data we can use for testing
rand.bin:
	echo 'Generating random data...'
	python3 -c "import numpy as np;\
	            np.random.seed(42);\
	            np.random.randn(1<<20).tofile('$@')"

data.feather: columns.txt
	echo 'Generating data from list of columns...'
	python3 generate_data.py --columns $^ --data $@ --min_rows=4096

# R packages are installed relative to R in the active env
# a minimal conda env works: conda create -n local_R r-base 
setup: 
	pip3 install -U patsy pandas feather-format scikit-sparse scipy py-bobyqa
	MAKE='make -j' Rscript -e 'install.packages(c("lme4", "optparse", "feather"), repos="cloud.r-project.org")'

# Create a conda env to run mixed with CUDA and numba support. Spoiler alert: the
# order of conda package installation is brittle b.c. of dependencies ...
#   * install conda-build early or fail
#   * install CUDA first and separately before r-base, else an
#     LD_LIBRARY_PATH fight erupts and CUDA nvcc breaks.
#   * py-bobyqa capitalization-fluid naming is critical. Uppercase for
#     PyPI or the tarball in meta.yaml is misnamed.  lowercase for
#     conda-build or else the package is not found.

CONDA_ENV = mixed_cuda
setup_conda: 
	{ \
	. $$(conda info --base)/etc/profile.d/conda.sh; \
	conda create -n ${CONDA_ENV}; \
	conda activate ${CONDA_ENV}; \
	hash -r; \
	conda info -e | grep "*" ; \
	conda install python pip cudatoolkit-dev numba conda-build -c defaults -c conda-forge -y; \
	conda install patsy feather-format scikit-sparse -c defaults -c conda-forge -y; \
	rm -rf /tmp/py-bobyqa; \
	conda skeleton pypi Py-BOBYQA --output-dir /tmp/py-bobyqa; \
	conda-build /tmp/py-bobyqa; \
	conda install -c file://$${CONDA_PREFIX}/conda-bld py-bobyqa -y; \
	conda install r-base -y ; \
	MAKE='make -j' Rscript -e 'install.packages(c("lme4", "optparse", "feather"), repos="cloud.r-project.org")'; \
	}

clean:
	rm -rf $(wildcard *.feather *.bin __pycache__)
