WEBRTC_PATH ?=
WEBRTC_LIBS_PATH ?=
WEBRTC_INC_PATH ?=
CXXFLAGS ?= -std=c++14 -Wall -Wextra -Wno-unused-parameter
BUILD_TYPE ?= debug
BUILD ?= build/$(BUILD_TYPE)

CXXFLAGS += -DCPPHTTPLIB_OPENSSL_SUPPORT
ifeq ($(BUILD_TYPE),debug)
	CXXFLAGS += -g
endif
ifeq ($(BUILD_TYPE),sanitize)
	CXXFLAGS += -g -fsanitize=address,undefined
	LDFLAGS += -fsanitize=address,undefined
endif
ifeq ($(BUILD_TYPE),release)
	CXXFLAGS += -O2
endif

HDRS = $(wildcard src/*.h)
SRCS = src/HttpServer.cc src/main.cc
WEB = web/index.html web/script.js
INCLUDE = third_party/cpp-httplib
WEBRTC_LIBS = libwebrtc.a third_party/boringssl/libboringssl.a
WEBRTC_INCS = third_party/boringssl/src/include

DEPS = $(patsubst %,$(BUILD)/%.d,$(SRCS))
OBJS = \
	$(patsubst %,$(BUILD)/%.o,$(SRCS)) \
	$(patsubst %,$(BUILD)/gen/%.c.o,$(WEB))
CXXFLAGS += \
	$(patsubst %,-isystem%,$(INCLUDE)) -I$(WEBRTC_INC_PATH) \
	$(patsubst %,-isystem$(WEBRTC_INC_PATH)/%,$(WEBRTC_INCS))
LDLIBS = \
	$(patsubst %,$(WEBRTC_LIBS_PATH)/%,$(WEBRTC_LIBS)) \
	-lpthread \

# Re-run Make with WebRTC paths set
.PHONY: all
all: webrtc/.completed
	$(MAKE) \
		WEBRTC_LIBS_PATH="$$(cat webrtc/.libspath)" \
		WEBRTC_INC_PATH="$$(cat webrtc/.incpath)" \
		phonecam-all

.PHONY: phonecam-all
phonecam-all: $(BUILD)/phonecam

.PHONY: build-webrtc
build-webrtc:
	(cd webrtc && ./build.sh $(WEBRTC_PATH))

# Build WebRTC
webrtc/.completed:
	(cd webrtc && ./build.sh $(WEBRTC_PATH))

# Generate a dependency graph .d file from a C++ source file
$(BUILD)/%.cc.d: %.cc $(HDRS)
	@mkdir -p $(@D)
	(: DEP :); $(CXX) $(CXXFLAGS) -MM -MF $@ -MT $(BUILD)/obj/$<.o $<

# Compile a single C++ source file
$(BUILD)/%.cc.o: %.cc
	@mkdir -p $(@D)
	(: CXX :); $(CXX) $(CXXFLAGS) -o $@ -c $<

# Compile a sigle generated C file
$(BUILD)/gen/%.c.o: $(BUILD)/gen/%.c
	(: CC  :); $(CC) -o $@ -c $<

# Generate C files from web files
$(BUILD)/gen/web/%.c: web/%
	@mkdir -p $(@D)
	(: XXD :); xxd -i $< $@

# Link
$(BUILD)/phonecam: $(OBJS)
	@mkdir -p $(@D)
	(: LNK :); $(CXX) $(LDFLAGS) -o $@ $^ $(LDLIBS)

.PHONY: clean
clean:
	rm -rf $(BUILD)

.PHONY: clean-webrtc
clean-webrtc:
	[ -e webrtc/.datapath ] && rm -rf "$$(cat webrtc/.datapath)"
	rm -f webrtc/.incpath webrtc/.libspath webrtc/.completed

ifeq ($(MAKECMDGOALS),phonecam-all)
-include $(DEPS)
endif
