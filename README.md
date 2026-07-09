# MoonBit MQTT 3.1.1 Packet Codec

MoonBit MQTT 是一个面向 MQTT 3.1.1 常用控制包的字节级编解码基础库。它提供固定头、Remaining Length、MQTT UTF-8 String、Binary Data，以及常用控制包的编码、解码和基础合法性校验。

本项目不是 MQTT 客户端，也不包含 TCP、WebSocket、TLS、Broker 会话、QoS 重传状态机或 MQTT 5.0 支持。

## 当前范围

| 能力 | 当前状态 |
| --- | --- |
| Remaining Length | 编码、解码、范围校验 |
| MQTT UTF-8 String | 编码、解码、UTF-8 校验 |
| MQTT Binary Data | 编码、解码，适用于 CONNECT password / will message 等二进制字段 |
| Fixed Header | 解码；各控制包解码时校验消息类型、QoS/retain/DUP 保留位和包长 |
| Packet framing | 根据固定头计算单个 MQTT packet 总长度，判断缓冲区是否包含完整 packet |
| Generic packet decoder | 按控制包类型分发到对应的已实现解码器 |
| CONNECT | 编码、解码 |
| CONNACK | 编码、解码 |
| PUBLISH | QoS 0/1/2 数据包编码、解码；不实现重传状态机 |
| PUBACK / PUBREC / PUBREL / PUBCOMP | 编码、解码 packet identifier |
| SUBSCRIBE | 编码、解码 topic filter 与 requested QoS |
| SUBACK | 编码、解码返回码 |
| UNSUBSCRIBE | 编码、解码 topic filter |
| UNSUBACK | 编码、解码 packet identifier |
| PINGREQ / PINGRESP / DISCONNECT | 编码、解码空控制包 |

## 明确不支持

- 不建立网络连接，不发送或接收 TCP/WebSocket 数据。
- 不实现 MQTT 客户端对象、连接管理、自动重连、心跳调度或订阅回调。
- 不实现 Broker、会话持久化、保留消息、遗嘱投递语义。
- 不实现 QoS 1/2 的重发、确认队列、状态机和消息去重。
- 不实现 TLS/SSL。
- 不实现 MQTT 5.0 属性、原因码和扩展控制包。

## 使用示例

### 编码 CONNECT

```moonbit
let packet = encode_connect({
  client_id: "moon",
  username: None,
  password: None,
  will_topic: None,
  will_message: None,
  keep_alive: 60,
  flags: {
    username: false,
    password: false,
    will_retain: false,
    will_qos: QoS0,
    will_flag: false,
    clean_session: true,
  },
})
```

### 编码和解码 PUBLISH

```moonbit
let encoded = encode_publish({
  topic: "sensor/temp",
  payload: b"24.5",
  qos: QoS1,
  message_id: Some(7),
  retain: false,
  dup: false,
})

let decoded = match encoded {
  Ok(packet) => decode_publish(packet)
  Err(e) => Err(e)
}
```

### 解码 SUBACK

```moonbit
let suback = decode_suback([0x90, 0x04, 0x00, 0x09, 0x00, 0x80])
```

## 本地验证

```bash
moon check
moon test
```

当前测试包含 19 个字节级测试，覆盖 Remaining Length、字符串和二进制字段、packet framing、generic packet decoder、CONNECT、CONNACK、PUBLISH QoS 0/1/2、QoS 确认包、SUBSCRIBE、SUBACK、UNSUBSCRIBE、UNSUBACK、PINGREQ、PINGRESP、DISCONNECT，以及部分非法固定头和包长错误。

## 项目定位

本项目适合作为 MoonBit MQTT 客户端、Broker、协议测试工具或教学示例的底层包编解码组件。上层网络传输、会话和重传逻辑需要在本库之外实现。

## License

Apache-2.0
