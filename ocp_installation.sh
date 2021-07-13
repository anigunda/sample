#!/bin/bash
## Title:		Automated OCP Installation
## Description:	This script is developed to be executed on Jenkins by connecting it to a GIT repo with OCP specific installation files
## Author:		Anirudh Gunda <angunda@deloitte.com; anirudh.a.gunda@calheers.ca.gov>
## Date:		7/12/2021
## Version:		1.0

set -e
# Helper function to print errors
function print_error {
   local __err_msg="$1"
   >&2 printf "[ERROR] ${__err_msg}\n"
   exit 1
}

# Helper function to print informational messages
function print_info {
   local __info_msg="$1"
   printf "[INFO] ${__info_msg}\n"
}

# This function is used to check if the installer binary exists
# The binary is further used to install the entire OCP setup
function check_installer {
	if [[ -f ${INSTALLER_TAR} ]]
	then
		print_info "Installer Archive Found: (${INSTALLER_TAR})"
		print_info "Extracting to ${WORK_DIR}.."
		tar xzf ${INSTALLER_TAR} --directory ${WORK_DIR}
	else
		print_error "Installer Archive Not-found: (${INSTALLER_TAR})"
	fi
	if [[ -f ${INSTALLER_FILE} ]]
	then
		print_info "Installer Binary Found: (${INSTALLER_FILE})"
		OCP_VERSION=`${INSTALLER_FILE} version | head -1 | cut -f2 -d " "`
		print_info "OpenShift Installer Version: ${OCP_VERSION}"
	else
		print_error "Installer Binary Not-found: (${INSTALLER_FILE})"
	fi
}

# This function is used to check if the valid properties file exists
# This property file is used to replace the values in install-config.template
function check_properties {
	if [[ -f ${PROPERTY_FILE} ]]
	then
		print_info "Property File Found: (${PROPERTY_FILE})"
	else
		print_error "Property File Not-found: (${PROPERTY_FILE})"
	fi
}

# This function is used to generate a final install-config.yaml
# The install-config.yaml generated here is further used as input to OCP creation
function generate_config {
	envsubst ${MASTER_INSTANCE_TYPE} ${WORKER_INSTANCE_TYPE} ${WORKER_COUNT} ${OCP_CLUSTER} < ${INSTALL_TEMPLATE} > ${INSTALL_TEMPLATE}
	for EXP_PROPS in $(cat ${PROPERTY_FILE} | jq -r "to_entries|map(\"\(.key)=\(.value|tostring)\")|.[]" );
	do
		export ${EXP_PROPS}
	done
	envsubst < ${INSTALL_TEMPLATE} > ${INSTALL_CONFIG}
}

# This function is used to copy the install-config.yaml to a final install directory
# Also, it is used to run the installer binary which triggers and orchestrates the OCP installation
function install_ocp {
	mkdir -p ${INSTALL_DIR}
	cp ${INSTALL_CONFIG} ${INSTALL_DIR}/
	echo "${INSTALLER_FILE} create cluster --dir=${INSTALL_DIR} --log-level=debug"
}

# Variables (both from Jenkins and Custom)
WORK_DIR=${WORKSPACE}
INSTALL_DIR=/opt/${OCP_CLUSTER}
INSTALLER_TAR=${WORK_DIR}/openshift-install-linux.tar.gz
INSTALLER_FILE=${WORK_DIR}/openshift-install
PROPERTY_FILE=${WORK_DIR}/${OCP_CLUSTER}.properties
INSTALL_TEMPLATE=${WORK_DIR}/install-config.template
INSTALL_CONFIG=${WORK_DIR}/install-config.yaml

# Function Calls
check_installer
check_properties
generate_config
install_ocp