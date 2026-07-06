# MoonBit MQTT 协议编码器/解码器库

一个用于 MoonBit 编程语言的 MQTT 3.1.1 协议编码器/解码器实现，提供MQTT消息的编码和解码功能。

[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
[![MoonBit](https://img.shields.io/badge/MoonBit-0.1.0-orange.svg)](https://moonbitlang.com)

## 项目简介

MoonBit MQTT 协议库提供 MQTT 3.1.1 协议的完整编码和解码功能，为 MoonBit 生态系统提供构建物联网消息通信应用的基础组件。本项目实现了 MQTT 3.1.1 协议规范（OASIS标准）的核心数据结构和编解码逻辑，可作为构建完整MQTT客户端或服务器的基础。

本项目遵循 MQTT 3.1.1 协议规范，提供类型安全的API设计，充分利用MoonBit的强类型系统确保协议实现的正确性。

## 核心功能

- **协议数据结构**：完整的MQTT 3.1.1消息类型和数据结构定义
- **消息编码**：支持所有MQTT消息类型的编码（CONNECT、PUBLISH、SUBSCRIBE等）
- **消息解码**：支持所有MQTT消息类型的解码（CONNACK、SUBACK等）
- **QoS支持**：支持QoS 0、QoS 1、QoS 2的数据结构
- **类型安全**：利用MoonBit类型系统确保协议正确性

## 安装方式

### 通过 mooncakes.io 安装

```bash
moon add username/moonbit-mqtt
```

### 从源码构建

```bash
git clone https://github.com/username/moonbit-mqtt.git
cd moonbit-mqtt
moon build
```

## 使用方法

### 编码CONNECT消息

```moonbit
let connect = {
  client_id: "test_client",
  username: Some("username"),
  password: Some("password"),
  will_topic: None,
  will_message: None,
  keep_alive: 60,
  flags: {
    username: true,
    password: true,
    will_retain: false,
    will_qos: QoS0,
    will_flag: false,
    clean_session: true,
  },
}
let packet = encode_connect(connect)
```

### 编码PUBLISH消息

```moonbit
let publish = {
  topic: "test/topic",
  payload: "Hello MQTT".to_bytes(),
  qos: QoS0,
  message_id: None,
  retain: false,
  dup: false,
}
let packet = encode_publish(publish)
```

### 解码CONNACK消息

```moonbit
let connack_bytes = [0x20u8, 0x02u8, 0x00u8, 0x00u8]
let connack = decode_connack(connack_bytes)
// connack.return_code == ConnectionAccepted
```

### 解码SUBACK消息

```moonbit
let suback_bytes = [0x90u8, 0x03u8, 0x00u8, 0x01u8, 0x00u8]
let suback = decode_suback(suback_bytes)
// suback.message_id == 1
// suback.return_codes == [SuccessQoS0]
```

## 测试

运行测试：

```bash
moon test
```

## 项目状态

- ✅ MQTT 3.1.1 协议数据结构定义
- ✅ 所有消息类型的编码功能
- ✅ 所有消息类型的解码功能
- ✅ QoS 0/1/2 数据结构支持
- ✅ 完整的单元测试覆盖
- 🚧 网络传输层集成（计划中）
- 🚧 完整MQTT客户端实现（计划中）

## 技术特点

- **纯 MoonBit 实现**：完全使用 MoonBit 编写，无外部依赖
- **类型安全**：利用 MoonBit 的类型系统确保协议正确性
- **协议完整**：支持 MQTT 3.1.1 规范的所有消息类型
- **轻量级**：最小化依赖，适合嵌入式和 WebAssembly 环境
- **可测试**：完整的单元测试覆盖编码解码逻辑
- **基础组件**：可作为构建完整MQTT客户端/服务器的基础

## 开发计划

- [ ] 添加网络传输层支持（TCP/WebSocket）
- [ ] 实现完整的MQTT客户端状态机
- [ ] 添加Last Will和 Testament支持
- [ ] 添加TLS/SSL加密支持
- [ ] 性能优化和基准测试
- [ ] 添加MQTT 5.0协议支持

## 许可证

本项目采用 Apache-2.0 许可证。

## 贡献

欢迎提交 Issue 和 Pull Request！

## 联系方式

- 项目地址：https://github.com/username/moonbit-mqtt
- 问题反馈：通过 GitHub Issues
- 邮件联系：[项目维护者邮箱]

## 致谢

感谢 MoonBit 团队提供的优秀编程语言和工具链支持。
