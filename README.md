# MoonBit MQTT 客户端库

一个用于 MoonBit 编程语言的 MQTT 3.1.1 客户端实现，支持基本的发布/订阅功能。

[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
[![MoonBit](https://img.shields.io/badge/MoonBit-0.1.0-orange.svg)](https://moonbitlang.com)

## 项目简介

MoonBit MQTT 是一个轻量级的 MQTT 客户端库，为 MoonBit 生态系统提供物联网消息通信能力。该项目实现了 MQTT 3.1.1 协议的核心功能，包括连接管理、消息发布、主题订阅等。

本项目遵循 MQTT 3.1.1 协议规范（OASIS标准），提供类型安全的API设计，充分利用MoonBit的强类型系统确保协议实现的正确性。

## 核心功能

- **连接管理**：支持 MQTT broker 连接、断开连接
- **消息发布**：支持 QoS 0 消息发布
- **主题订阅**：支持主题订阅和取消订阅
- **认证支持**：支持用户名/密码认证
- **Keep-Alive**：可配置的心跳保持连接

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

### 创建客户端

```moonbit
let client = Client::new("localhost", 1883, "test_client")
```

### 设置认证信息

```moonbit
let client = Client::new("localhost", 1883, "test_client")
  |> Client::set_credentials("username", "password")
```

### 设置 Keep-Alive

```moonbit
let client = Client::new("localhost", 1883, "test_client")
  |> Client::set_keep_alive(60)
```

### 连接到 Broker

```moonbit
let client = Client::new("localhost", 1883, "test_client")
let result = client.connect()
match result {
  Ok(connected_client) => // 连接成功
  Err(_) => // 连接失败
}
```

### 发布消息

```moonbit
let client = Client::new("localhost", 1883, "test_client")
let connected_client = match client.connect() {
  Ok(c) => c
  Err(_) => abort("Connection failed")
}
let payload = "Hello MQTT".to_bytes()
let _ = connected_client.publish("test/topic", payload)
```

### 订阅主题

```moonbit
let client = Client::new("localhost", 1883, "test_client")
let connected_client = match client.connect() {
  Ok(c) => c
  Err(_) => abort("Connection failed")
}
let _ = connected_client.subscribe("test/topic", QoS0)
```

### 取消订阅

```moonbit
let client = Client::new("localhost", 1883, "test_client")
let connected_client = match client.connect() {
  Ok(c) => c
  Err(_) => abort("Connection failed")
}
let _ = connected_client.unsubscribe("test/topic")
```

### 断开连接

```moonbit
let client = Client::new("localhost", 1883, "test_client")
let connected_client = match client.connect() {
  Ok(c) => c
  Err(_) => abort("Connection failed")
}
let disconnected_client = connected_client.disconnect()
```

## 测试

运行测试：

```bash
moon test
```

## 项目状态

- ✅ 基础数据结构定义
- ✅ 连接管理
- ✅ 消息发布（QoS 0）
- ✅ 主题订阅/取消订阅
- ✅ 用户认证
- ✅ Keep-Alive 支持
- 🚧 QoS 1/2 支持（计划中）
- 🚧 消息接收（计划中）
- 🚧 Last Will 和 Testament（计划中）

## 技术特点

- **纯 MoonBit 实现**：完全使用 MoonBit 编写，无外部依赖
- **类型安全**：利用 MoonBit 的类型系统确保协议正确性
- **轻量级**：最小化依赖，适合嵌入式和 WebAssembly 环境
- **可测试**：完整的单元测试覆盖

## 开发计划

- [ ] 完善 QoS 1 和 QoS 2 支持
- [ ] 实现消息接收和回调机制
- [ ] 添加 Last Will 和 Testament 支持
- [ ] 支持 WebSocket 传输
- [ ] 添加 TLS/SSL 加密支持
- [ ] 性能优化和基准测试
- [ ] 添加更多MQTT协议特性支持
- [ ] 完善错误处理和重连机制

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
