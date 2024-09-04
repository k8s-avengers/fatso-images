#!/usr/bin/env bash

function config_mkosi_init::output_raw_gz() {
	log info "output_rawgz: Output is going to be raw .img with gzip compression (.img.gz)"
}

function mkosi_script_post_mkosi_host::output_raw_gz() {
	: "${IMAGE_FLAVOR_VERSION_ID:?IMAGE_FLAVOR_VERSION_ID is not set, cannot continue.}" # set by common_base

	declare -r raw_outfile="/out/image.raw"
	declare -r final_dist_file="/dist/${IMAGE_FLAVOR_VERSION_ID}.img.gz"
	log info "Output image will be ${raw_outfile}"
	log info "Compressed output image will be ${final_dist_file}"

	declare size_orig_human size_compress_human
	size_orig_human=$(du --si "${raw_outfile}" | cut -f 1)
	log info "Output image ${raw_outfile} size ${size_orig_human}"

	# Compress the image from raw_outfile to final_dist_file, using pigz
	log info "Compressing image to ${final_dist_file}"
	pigz -1 -c "${raw_outfile}" > "${final_dist_file}"
	size_compress_human=$(du --si "${final_dist_file}" | cut -f 1)
	log info "Done compressing image to ${final_dist_file} from ${size_orig_human} to ${size_compress_human}."
}
