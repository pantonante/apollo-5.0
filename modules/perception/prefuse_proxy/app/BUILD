load("//tools:cpplint.bzl", "cpplint")

package(default_visibility = ["//visibility:public"])

cc_binary(
    name = "libperception_prefuse_proxy.so",
    linkshared = True,
    linkstatic = False,
    deps = [":perception_component_inner_prefuse_proxy"],
)

cc_library(
    name = "perception_component_inner_prefuse_proxy",
    srcs = ["prefuse_proxy.cc"],
    hdrs = ["prefuse_proxy.h"],
    copts = [
        '-DMODULE_NAME=\\"perception\\"',
    ],
    deps = [
        "//cyber",
        "//modules/common/util",
        "//modules/common/math",
        "//modules/common/proto:error_code_proto",
        "//modules/common/proto:geometry_proto",
        "//modules/common/proto:header_proto",
        "//modules/common/time",
        "//modules/drivers/proto:sensor_proto",
        "//modules/map/proto:map_proto",
        "//modules/perception/base",
        "//modules/perception/proto:perception_proto",
        "//modules/perception/fusion/base",
        "//modules/perception/onboard/inner_component_messages",
        "//modules/perception/lib/utils",
        "//modules/perception/prefuse_proxy/proto:prefuse_proto",
        "@eigen",
    ],
    alwayslink = True,
)

cpplint()