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

name = "zbhzs1/moonbit-mqtt"

version = "0.1.0"

readme = "README.md"

repository = "https://github.com/zbhzs1/moonbit-mqtt"

license = "Apache-2.0"

keywords = [ "mqtt", "iot", "codec", "protocol", "moonbit" ]

preferred_target = "wasm-gc"

description = "MQTT 3.1.1 packet codec helpers for MoonBit without transport or client runtime"
