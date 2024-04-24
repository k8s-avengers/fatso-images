#!/usr/bin/env bash

# "Korok" 🌱 is a reference to the Legend of Zelda: Breath of the Wild, where you find hidden Korok seeds throughout the world.
# This a developer/debugging aid to help you find the correct methods to use in certain steps of the build process.
# Enable it and find the 🌱's spread around in the logs; maybe use it as template for writing your own fragments.

# Register this fragment/file to be included in the Dockerfile build process;
# any changes done here will cause hash/cache misses and possibly redownload/reinstalls!
# If you're not making changes at the Dockerfile level, don't enable those.
function config_mkosi_init::find_the_korok() {
	log korok "You found me! config_mkosi_init::find_the_korok - sans numbering; should be the second korok."

	declare -g -a BUILDER_FRAGMENTS_LATE # global
	BUILDER_FRAGMENTS_LATE+=("korok")

	# declare -g -a BUILDER_FRAGMENTS_EARLY # global               # --> disabled for now, see below
	# BUILDER_FRAGMENTS_EARLY+=("korok")                           # --> disabled for now, see below
}

# --> Commented out as it causes cache invalidation before the big apt install when enabled.
# function mkosi_script_builder_dockerfile_early_host::find_the_korok() {
# 	# NOTE: to use this, add the fragment name to BUILDER_FRAGMENTS_EARLY in config_mkosi_init::find_the_korok
# 	log korok "You found me! mkosi_script_builder_dockerfile_early_host::find_the_korok - I'm inside a Dockerfile, at the very beginning!"
# }

function mkosi_script_builder_dockerfile_late_host::find_the_korok() {
	# NOTE: to use this, add the fragment name to BUILDER_FRAGMENTS_LATE in config_mkosi_init::find_the_korok (already done as example)
	log korok "You found me! mkosi_script_builder_dockerfile_late_host::find_the_korok - I'm inside a Dockerfile, almost at the end!"
}

function config_mkosi_init::050_early_find_the_korok() {
	log korok "You found me! config_mkosi_init::050_early_find_the_korok - this should be the first korok you find!"
}

function config_mkosi_init::950_late_find_the_korok() {
	log korok "You found me! config_mkosi_init::950_late_find_the_korok - runs late and should be the third korok you find!"
}

function config_mkosi_pre::find_the_korok() {
	log korok "You found me! config_mkosi_pre::find_the_korok - I run on the host during configuration stage."
}

function config_mkosi_post::find_the_korok() {
	log korok "You found me! config_mkosi_post::find_the_korok - I run on the host during post-configuration stage."
}

function mkosi_script_postinst_host::find_the_korok() {
	log korok "You found me! mkosi_script_postinst_host::find_the_korok - I run inside mkosi, inside Docker, but NOT in the image chroot."
}

function mkosi_script_postinst_chroot::find_the_korok() {
	log korok "You found me! mkosi_script_postinst_chroot::find_the_korok - I run inside mkosi, inside Docker, inside the image chroot."
}

function mkosi_script_finalize_host::find_the_korok() {
	log korok "You found me! mkosi_script_finalize_chroot::find_the_korok - I run inside mkosi, inside Docker, but NOT in the image chroot."
}

function mkosi_script_finalize_chroot::find_the_korok() {
	log korok "You found me! mkosi_script_finalize_chroot::find_the_korok - I run inside mkosi, inside Docker, inside the image chroot."
}

function mkosi_script_pre_mkosi_host::find_the_korok() {
	log korok "You found me! mkosi_script_pre_mkosi_host::find_the_korok - I run before mkosi starts building the image, already inside Docker."
}

function mkosi_script_post_mkosi_host::find_the_korok() {
	log korok "You found me! mkosi_script_post_mkosi_host::find_the_korok - I run after mkosi is done building the image, still inside Docker."
}

# Trivia: did you know that Koroks despise vegetarians? "don't eat me!"
