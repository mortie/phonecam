#!/bin/sh

set -e

webrtc_checkout="branch-heads/m79"
build_type="Debug"
gn_args="
	is_debug=true
	proprietary_codecs=true
	rtc_build_examples=false
	rtc_include_tests=false
	rtc_use_h264=true
	rtc_use_gtk=false
	rtc_use_x11=false
	libyuv_include_tests=false
	treat_warnings_as_errors=false
	is_clang=false
	linux_use_bundled_binutils=false
	gold_path=\"\"
	use_custom_libcxx=false
	use_custom_libcxx_for_host=false
	use_gold=false
	use_sysroot=false
"

gn_args="$(printf "%s" "$gn_args" | sed 's/\t/  /g')"
origpath="$(pwd)"

if [ -z "$1" ]; then
	if [ -e .datapath ]; then
		datapath="$(cat .datapath)"
	else
		datapath="$(pwd)"
		echo "$datapath" > .datapath
	fi
else
	datapath="$1"
	echo "$datapath" > .datapath
fi

mkdir -p "$datapath"
cd "$datapath"

# Download depot_tools
if ! [ -e depot_tools/.complete ]; then
	rm -rf depot_tools
	git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
	touch depot_tools/.complete
fi

export PATH="$(pwd)/depot_tools:$PATH"

# Download webrtc
if ! [ -e webrtc-checkout/.complete ]; then
	rm -rf webrtc-checkout
	mkdir webrtc-checkout

	cd webrtc-checkout
		fetch --nohooks webrtc
		cd src
			git checkout "$webrtc_checkout"
		cd ..
		gclient sync -D
	cd ..

	touch webrtc-checkout/.complete
fi

# Compile webrtc
cd webrtc-checkout/src
	gn gen "out/$build_type" --args="$gn_args"

	if ! ninja -C "out/$build_type"; then
		# Linking might OOM kill a compiler, so try re-running with one job
		echo "Ninja process died (code $?), re-running with 1 thread in case it was an OOM kill..."
		ninja -C "out/$build_type" -j 1
	fi
cd ../..

cd "$origpath"
echo "$datapath/webrtc-checkout/src/out/$build_type/obj" > .libspath
echo "$datapath/webrtc-checkout/src" > .incpath
touch .completed
