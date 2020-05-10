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

DEPS = $(patsubst %,$(BUILD)/dep/%.d,$(SRCS))
OBJS = \
	$(patsubst %,$(BUILD)/obj/%.o,$(SRCS)) \
	$(patsubst %,$(BUILD)/gen/%.o,$(WEB))
CXXFLAGS += \
	$(patsubst %,-isystem%,$(INCLUDE)) -I$(WEBRTC_INC_PATH) \
	$(patsubst %,-isystem$(WEBRTC_INC_PATH)/%,$(WEBRTC_INCS))
LDLIBS = \
	$(patsubst %,$(WEBRTC_LIBS_PATH)/%,$(WEBRTC_LIBS)) \
	-lpthread \

.PHONY: all
all: webrtc/.libspath webrtc/.incpath
	$(MAKE) \
		WEBRTC_LIBS_PATH="$$(cat webrtc/.libspath)" \
		WEBRTC_INC_PATH="$$(cat webrtc/.incpath)" \
		receiver-all

.PHONY: receiver-all
receiver-all: $(BUILD)/receiver

webrtc/.libspath webrtc/.incpath:
	(cd webrtc && ./build.sh $(WEBRTC_PATH))

$(BUILD)/dep/%.cc.d: %.cc $(HDRS)
	@mkdir -p $(@D)
	(: DEP :); $(CXX) $(CXXFLAGS) -MM -MF $@ -MT $(BUILD)/obj/$<.o $<

$(BUILD)/obj/%.cc.o: %.cc
	@mkdir -p $(@D)
	(: CXX :); $(CXX) $(CXXFLAGS) -o $@ -c $<

$(BUILD)/gen/%.o: $(BUILD)/gen/%.c
	(: CC  :); $(CC) -o $@ -c $<

$(BUILD)/gen/web/%.c: web/%
	@mkdir -p $(@D)
	(: XXD :); xxd -i $< $@

$(BUILD)/receiver: $(OBJS)
	@mkdir -p $(@D)
	(: LNK :); $(CXX) $(LDFLAGS) -o $@ $^ $(LDLIBS)

.PHONY: clean
clean:
	rm -rf $(BUILD)

ifeq ($(MAKECMDGOALS),receiver-all)
-include $(DEPS)
endif
