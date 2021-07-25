package(default_visibility = ["//visibility:public"])

proto_library(
    name = "prefuse_proto_lib",
    srcs = [
        "prefuse_obstacle.proto",
    ],
    deps = [
        "//modules/common/proto:error_code_proto_lib",
        "//modules/common/proto:geometry_proto_lib",
        "//modules/common/proto:header_proto_lib",
    ],
)

cc_proto_library(
    name = "prefuse_proto",
    deps = [
        ":prefuse_proto_lib",
    ],
)

# py_proto(
#     name = "prefuse_proto_pb2",
#     src = "prefuse_obstacle.proto",
# )