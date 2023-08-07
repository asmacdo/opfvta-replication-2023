# We must allow others exactly use our script without modification
# Or its not replicable by others.
#
REGISTRY=docker.io
REPOSITORY=asmacdo

LATEX_IMAGE_NAME=latex-biber
LATEX_TAG=0.0.1-alpha

IMAGE_NAME=opfvta
IMAGE_TAG=2.0.0-alpha

FQDN_IMAGE=${REGISTRY}/${REPOSITORY}/${IMAGE_NAME}:${IMAGE_TAG}
FQDN_LATEX_IMAGE=${REGISTRY}/${REPOSITORY}/${LATEX_IMAGE_NAME}:${LATEX_TAG}

# PATH for scratch directory for intermidiate results etc
SCRATCH_PATH=/dartfs-hpc/scratch/${USER}

OCI_BINARY=docker
SING_BINARY=singularity

DISTFILE_CACHE_CMD :=

check_defined = \
    $(strip $(foreach 1,$1, \
        $(call __check_defined,$1,$(strip $(value 2)))))
__check_defined = \
    $(if $(value $1),, \
      $(error Undefined $1$(if $2, ($2))))

ifeq ($(DISTFILE_CACHE_PATH),)
    # If not set, don't add it as an option
else
    DISTFILE_CACHE_CMD =-v $(DISTFILE_CACHE_PATH):/var/cache/distfiles 
endif


.PHONY: all
all:
	@echo "Invoking default rule, which will just attempt to build the paper "
	@echo "without redoing the analysis.  If you would like to redo the entire "
	@echo "analysis, run  make analysis-oci or some other analysis-* flavor (check Makefile). "
	@echo "See README.md for more information."
	$(MAKE) article

#
# Data analysis
#
analysis-reproman:
	reproman run \
		-r discovery --sub slurm --orc datalad-no-remote \
		--jp num_processes=16 \
		--jp num_nodes=1 \
		--jp walltime=120:00:00 \
		make analysis-singularity

analysis-singularity:
	set -eu
	[ -n "${USER}" ]  # ATM SCRATCH_PATH above relies on $USER being defined 
	mkdir -p $(SCRATCH_PATH)
	$(SING_BINARY) run \
		-B ${PWD}/inputs/opfvta_bidsdata:/usr/share/opfvta_bidsdata \
		-B ${PWD}/inputs/mouse-brain-templates/mouse-brain-templates:/usr/share/mouse_brain_atlases \
		-B ${PWD}/outputs/:/outputs \
		-B $(SCRATCH_PATH):/scratch \
		-B ${PWD}/code/:/opt/src/ \
		--pwd /opt/src/ \
		code/images/opfvta-singularity/opfvta.sing \
		./produce-analysis.sh

analysis-oci:
	$(OCI_BINARY) run \
		-it \
		--rm \
		-v ${PWD}/inputs/opfvta_bidsdata:/usr/share/opfvta_bidsdata \
		-v ${PWD}/inputs/mouse-brain-templates/mouse-brain-templates:/usr/share/mouse_brain_atlases \
		-v ${PWD}/outputs/:/outputs \
		-v ${OPFVTA_SCRATCH_DIR}:/root/.scratch \
		-v ${PWD}/code/:/opt/src/ \
		${FQDN_IMAGE} \
		./produce-analysis.sh

#
# Paper build
#
.PHONY: article
article:
	$(MAKE) -C paper/source


#
# Containers management. oci- for Open Container Initiative
#
# Build data analysis container
analysis-oci-image:
	$(OCI_BINARY) build . $(DISTFILE_CACHE_CMD) \
		-f code/images/Containerfile \
		-t ${FQDN_IMAGE}

analysis-singularity-image:
	datalad install code/images/opfvta-singularity
	rm code/images/opfvta-singularity/opfvta.sing
	$(SING_BINARY) build code/images/opfvta-singularity/opfvta.sing docker://${FQDN_IMAGE}

# Build latex environment container
latex-oci-image:
	$(OCI_BINARY) build . $(DISTFILE_CACHE_CMD) \
		-f code/images/Containerfile.latex \
		-t ${FQDN_LATEX_IMAGE}

# Push containers
analysis-oci-push:
	$(OCI_BINARY) push ${FQDN_IMAGE}

latex-oci-push:
	$(OCI_BINARY) push ${FQDN_LATEX_IMAGE}


#
# Aux rules
#
submodule-data:
	cat inputs.txt | xargs datalad get
	datalad get inputs/opfvta_bidsdata
	datalad get code/images/opfvta-singularity
	datalad get code/opfvta

