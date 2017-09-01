#!/bin/bash

THIS_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

set -e

#=======================================
# Functions
#=======================================

RESTORE='\033[0m'
RED='\033[00;31m'
YELLOW='\033[00;33m'
BLUE='\033[00;34m'
GREEN='\033[00;32m'

function color_echo {
	color=$1
	msg=$2
	echo -e "${color}${msg}${RESTORE}"
}

function echo_fail {
	msg=$1
	echo
	color_echo "${RED}" "${msg}"
	exit 1
}

function echo_warn {
	msg=$1
	color_echo "${YELLOW}" "${msg}"
}

function echo_info {
	msg=$1
	echo
	color_echo "${BLUE}" "${msg}"
}

function echo_details {
	msg=$1
	echo "  ${msg}"
}

function echo_done {
	msg=$1
	color_echo "${GREEN}" "  ${msg}"
}

function validate_required_input {
	key=$1
	value=$2
	if [ -z "${value}" ] ; then
		echo_fail "[!] Missing required input: ${key}"
	fi
}

function validate_required_input_with_options {
	key=$1
	value=$2
	options=$3

	validate_required_input "${key}" "${value}"

	found="0"
	for option in "${options[@]}" ; do
		if [ "${option}" == "${value}" ] ; then
			found="1"
		fi
	done

	if [ "${found}" == "0" ] ; then
		echo_fail "Invalid input: (${key}) value: (${value}), valid options: ($( IFS=$", "; echo "${options[*]}" ))"
	fi
}

#=======================================
# Main
#=======================================

#
# Validate parameters
echo_info "Configs:"
echo_details "* workspace: $workspace"
echo_details "* scheme: $scheme"
echo_details "* configuration: $configuration"
echo_details "* clean: $clean"
echo_details "* arch: $arch"
echo_details "* codesign_identity: $codesign_identity"
echo_details "* xcodebuild_flags: $xcodebuild_flags"
echo_details "* use_xcpretty: $use_xcpretty"
echo_details "* output_dir: $output_dir"

echo

validate_required_input "workspace" $workspace
validate_required_input "scheme" $scheme
validate_required_input "configuration" $configuration
validate_required_input "clean" $clean
validate_required_input "arch" $arch
validate_required_input "codesign_identity" "$codesign_identity"
validate_required_input "xcodebuild_flags" "$xcodebuild_flags"
validate_required_input "use_xcpretty" "$use_xcpretty"
validate_required_input "output_dir" "$output_dir"

# this expansion is required for paths with ~
#  more information: http://stackoverflow.com/questions/3963716/how-to-manually-expand-a-special-variable-ex-tilde-in-bash
eval expanded_source_path="${output_dir}"

[ -d "${output_dir}" ] || mkdir -p $output_dir


CLEAN_FLAG=""
if [ "$clean" == "true" ]; then
  CLEAN_FLAG=" clean "
fi

XCPRETTY_FLAG=""
if [ "$use_xcpretty" == "true" ]; then
  set -o pipefail && \
    xcodebuild "-workspace" "$workspace" \
               "-scheme" "$scheme" \
               "-configuration" "$configuration" \
                -derivedDataPath "./build" \
                $CLEAN_FLAG "build" \
               "CODE_SIGN_IDENTITY=$codesign_identity" \
               "$xcodebuild_flags" | xcpretty
else
  set -o pipefail && \
    xcodebuild "-workspace" "$workspace" \
               "-scheme" "$scheme" \
               "-configuration" "$configuration" \
                -derivedDataPath "./build" \
                $CLEAN_FLAG "build" \
               "CODE_SIGN_IDENTITY=$codesign_identity" \
               "$xcodebuild_flags"
fi

ARCHIVE_PATH="./build/Build/Products/${configuration}-${arch}"

for FRAMEWORK_PATH in $ARCHIVE_PATH/*.framework*; do
  if [ -L "${FRAMEWORK_PATH}" ]; then
    echo "Symlinked..."
    FRAMEWORK_PATH="$(readlink "${FRAMEWORK_PATH}")"
  fi
  rsync -am "$FRAMEWORK_PATH" "$output_dir"
done

# --- Export Environment Variables for other Steps:
# You can export Environment Variables for other Steps with
#  envman, which is automatically installed by `bitrise setup`.
# A very simple example:
#  envman add --key EXAMPLE_STEP_OUTPUT --value 'the value you want to share'
# Envman can handle piped inputs, which is useful if the text you want to
# share is complex and you don't want to deal with proper bash escaping:
#  cat file_with_complex_input | envman add --KEY EXAMPLE_STEP_OUTPUT
# You can find more usage examples on envman's GitHub page
#  at: https://github.com/bitrise-io/envman

#
# --- Exit codes:
# The exit code of your Step is very important. If you return
#  with a 0 exit code `bitrise` will register your Step as "successful".
# Any non zero exit code will be registered as "failed" by `bitrise`.
