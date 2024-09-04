#!/usr/bin/env bash

function config_mkosi_init::output_vhdx() {
	log info "output_vhdx: Compressed output image will be VHDX subformat=dynamic, with extra 5Gb"
}

function mkosi_script_post_mkosi_host::output_vhdx() {
	: "${IMAGE_FLAVOR_VERSION_ID:?IMAGE_FLAVOR_VERSION_ID is not set, cannot continue.}" # set by common_base

	declare -r full_file_vhdx="/dist/${IMAGE_FLAVOR_VERSION_ID}.vhdx"
	log info "output_vhdx: VHDX output image will be ${full_file_vhdx}"

	log info "output_vhdx: Converting image to VHDX format, using qcow2 intermediary"
	declare original_raw_image="/out/image.raw"
	declare temp_qcow2_image="/out/image.qcow2"
	qemu-img convert -f raw -O qcow2 "${original_raw_image}" "${temp_qcow2_image}"
	rm -vf "${original_raw_image}"                                                                   # free up space
	qemu-img resize "${temp_qcow2_image}" +5G                                                        # resize the temporary
	qemu-img convert -f qcow2 -O vhdx -o subformat=dynamic "${temp_qcow2_image}" "${full_file_vhdx}" # convert the big temp to vhdx
	rm -vf "${temp_qcow2_image}"                                                                     # remove the temporary large qcow2, free space
	log info "output_vhdx: Done converting image to VHDX format"
	qemu-img info "${full_file_vhdx}" # show info
}
