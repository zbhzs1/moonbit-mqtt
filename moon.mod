// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "username/moonbit-mqtt"

version = "0.1.0"

readme = "README.md"

repository = "https://github.com/username/moonbit-mqtt"

license = "Apache-2.0"

keywords = ["mqtt", "iot", "messaging", "publish-subscribe", "protocol"]

preferred_target = "wasm-gc"

description = "MQTT 3.1.1 client implementation for MoonBit with full protocol support"
