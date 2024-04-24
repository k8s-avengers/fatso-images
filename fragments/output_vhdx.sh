#!/usr/bin/env bash

function config_mkosi_init::output_vhdx() {
	declare -g -a BUILDER_FRAGMENTS_LATE # global
	BUILDER_FRAGMENTS_LATE+=("output_vhdx")

	# Tell the builder we'll be changing things; make them read-only to avoid other fragments to conflict
	declare -r -g OUTPUT_IMAGE_FILE_RAW="${OUTPUT_DIR}/image.vhdx"
	declare -r -g -r DIST_FILE_IMG_RAW_GZ="${DIST_DIR}/${FLAVOR}-v${IMAGE_VERSION}.vhdx.gz"
}

function mkosi_script_builder_dockerfile_late_host::output_vhdx() {
	# NOTE: to use this, add the fragment name to BUILDER_FRAGMENTS_LATE in config_mkosi_init::output_vhdx (already done as example)
	log info "output_vhdx: Installing qemu-utils for vhdx conversion"
	apt-get install -y qemu-utils # @TODO: what if it was an EL-based builder?
}

function mkosi_script_post_mkosi_host::output_vhdx() {
	log korok "You found me! mkosi_script_post_mkosi_host::output_vhdx - I run after mkosi is done building the image, still inside Docker."
	declare original_raw_image="/out/image.raw"
	declare temp_qcow2_image="/out/image_temp.qcow2"
	declare full_file_vhdx="/out/image.vhdx"
	qemu-img convert -f raw -O qcow2 "${original_raw_image}" "${temp_qcow2_image}"
	rm -vf "${original_raw_image}"                                                                   # free up space
	qemu-img resize "${temp_qcow2_image}" +5G                                                        # resize the temporary
	qemu-img convert -f qcow2 -O vhdx -o subformat=dynamic "${temp_qcow2_image}" "${full_file_vhdx}" # convert the big temp to vhdx
	rm -vf "${temp_qcow2_image}"                                                                     # remove the temporary large qcow2, free space
	log info "output_vhdx: Done converting image to VHDX format"
	qemu-img info "${full_file_vhdx}" # show info
}
