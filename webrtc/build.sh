#!/bin/sh

set -e

webrtc_checkout="branch-heads/m79"
build_type="Debug"
gn_args="is_debug=true"

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

if ! [ -e depot_tools/.complete ]; then
	rm -rf depot_tools
	git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
	touch depot_tools/.complete
fi

export PATH="$(pwd)/depot_tools:$PATH"

if ! [ -e webrtc-checkout/.complete ]; then
	rm -rf webrtc-checkout
	mkdir webrtc-checkout

	cd webrtc-checkout
		fetch --nohooks webrtc
		cd src
			git checkout "$webrtc_checkout"
		cd ..
		gclient sync
	cd ..

	touch webrtc-checkout/.complete
fi

if ! [ -e "webrtc-checkout/src/out/$build_type/.complete" ]; then
	cd webrtc-checkout/src
		rm -rf "out/$build_type"
		gn gen "out/$build_type" --args="$gn_args"

		# Linking might OOM kill a compiler, so try re-running with one job
		ninja -C "out/$build_type" -j 1
	cd ../..

	touch "webrtc-checkout/src/out/$build_type/.complete"
fi

cd "$origpath"
echo "$datapath/webrtc-checkout/src/out/$build_type/obj" > .libspath
echo "$datapath/webrtc-checkout/src" > .incpath
