# PhoneCam

Use any device with a camera and a web browser as a web camera.
The camera shows up as any other web camera on the host Linux machine.

Status: Very early.

## Build

To build PhoneCam, run:

	git clone --recursive https://github.com/mortie/phonecam.git
	cd phonecam
	make BUILD_TYPE=release -j 8

A build will take a _long_ time because the build script will first download
and compile Google's WebRTC library. On my system, this takes about 1 hour and
40 minutes (though that's using a spinning rust drive for space reasons;
I assume it would be significantly faster on an SSD).

WebRTC also takes a lot of space (around 16 GB). You can make the build script
download and build WebRTC into a different directory by replacing the `make` command
above with:

	make BUILD_TYPE=release WEBRTC_PATH=/destination/path -j 8

For example, I build with this command to put WebRTC on my external hard drive
(which is mounted in `/mnt/HDD`):

	make BUILD_TYPE=release WEBRTC_PATH=/mnt/HDD/data/phonecam-rtc -j 8

## Usage

(This stuff doesn't work yet, because PhoneCam is far from done.
This section describes how it's intended to work when it's done.)

After building, you will have a self-contained executable in `build/$BUILD_TYPE/phonecam`
(for example `build/release/phonecam` if you built with `BUILD_TYPE=release`).
Run that program:

	./build/release/phonecam

It will tell you your IP address and port number (for example `10.0.101.29:8080`).

Now, navigate to `https://<IP>:<port>` (for example `https://10.0.101.29:8080`)
on your phone/tablet/laptop/whatever you want to use as a webcam.

Next, accept whatever warning your browser shows; PhoneCam creates a self-signed
HTTPS certificate.

Next, click the "connect" button in the browser. It should now start streaming
video from its camera to your Linux host, and its output should be available
as a web camera.

## WebRTC build options

Building WebRTC provides a lot of options. Most of the time, you probably don't
need to change anything, but if you want to change something (for example,
if you're cross compiling, or don't want proprietary codecs, or want to use
WebRTC's toolchain instead of your host system's), you can change the options
given to `gn gen` by changing `gn_args` in `webrtc/build.sh`.

To re-run GN and ninja for webrtc, run `make build-webrtc`.
