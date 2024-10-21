#!/usr/bin/env bash

function config_mkosi_init::output_qcow2() {
	log info "output_qcow2: Compressed output image will be qcow2 with extra 5Gb"
}

function mkosi_script_post_mkosi_host::output_qcow2() {
	: "${IMAGE_FLAVOR_VERSION_ID:?IMAGE_FLAVOR_VERSION_ID is not set, cannot continue.}" # set by common_base

	declare -r full_file_qcow2="/dist/${IMAGE_FLAVOR_VERSION_ID}.qcow2"
	log info "output_qcow2: QCOW2 output image will be ${full_file_qcow2}"

	log info "output_qcow2: Converting image to QCOW2 format"
	declare original_raw_image="/out/image.raw"
	qemu-img convert -f raw -O qcow2 "${original_raw_image}" "${full_file_qcow2}"
	rm -vf "${original_raw_image}"           # free up space
	qemu-img resize "${full_file_qcow2}" +5G # resize the temporary
	log info "output_qcow2: Done converting image to QCOW2 format"
	qemu-img info "${full_file_qcow2}" # show info

	# Hack: if running under GitHub actions, further compress the .qcow2 into .qcow2.gz so it fits in GitHub releases (2Gb limit)
	log info "output_qcow2: Checking if running under GitHub Actions: GITHUB_OUTPUT: ${GITHUB_OUTPUT}"
	if [[ "x${GITHUB_OUTPUT}x" != "xx" ]]; then
		declare -r full_file_qcow2_gz="${full_file_qcow2}.gz"
		log info "output_qcow2: Compressing QCOW2 image to QCOW2.GZ for GitHub Actions"
		pigz -1 "${full_file_qcow2}"
		log info "output_qcow2: Done compressing QCOW2 image to QCOW2.GZ for GitHub Actions"

		# If full_file_qcow2_gz is larger than 2Gb exactly, log an error, delete the file, but do not error out
		declare -i size_qcow2_gz_bytes
		size_qcow2_gz_bytes=$(stat --format="%s" "${full_file_qcow2_gz}")
		if [[ ${size_qcow2_gz_bytes} -gt 2147483648 ]]; then
			log error "output_qcow2: Compressed QCOW2 image is larger than 2Gb, GitHub Actions will not accept it. Deleting ${full_file_qcow2_gz}"
			rm -vf "${full_file_qcow2_gz}"
		fi
	fi

}
