// MQTT 3.1.1 packet codec.
// Scope: byte-level packet encode/decode helpers. This package does not
// implement TCP/WebSocket transport, broker sessions, or MQTT client state.

///|
pub(all) enum MessageType {
  CONNECT
  CONNACK
  PUBLISH
  PUBACK
  PUBREC
  PUBREL
  PUBCOMP
  SUBSCRIBE
  SUBACK
  UNSUBSCRIBE
  UNSUBACK
  PINGREQ
  PINGRESP
  DISCONNECT
} derive(Eq, Debug)

///|
pub(all) enum QoS {
  QoS0
  QoS1
  QoS2
} derive(Eq, Debug)

///|
pub(all) struct FixedHeader {
  message_type : MessageType
  dup : Bool
  qos : QoS
  retain : Bool
  remaining_length : Int
  header_len : Int
} derive(Debug)

///|
pub(all) struct ConnectFlags {
  username : Bool
  password : Bool
  will_retain : Bool
  will_qos : QoS
  will_flag : Bool
  clean_session : Bool
} derive(Debug)

///|
pub(all) struct Connect {
  client_id : String
  username : String?
  password : Bytes?
  will_topic : String?
  will_message : Bytes?
  keep_alive : Int
  flags : ConnectFlags
} derive(Debug)

///|
pub(all) enum ConnackReturnCode {
  ConnectionAccepted
  UnacceptableProtocolVersion
  IdentifierRejected
  ServerUnavailable
  BadUserNameOrPassword
  NotAuthorized
} derive(Eq, Debug)

///|
pub(all) struct Connack {
  session_present : Bool
  return_code : ConnackReturnCode
} derive(Debug)

///|
pub(all) struct Publish {
  topic : String
  payload : Bytes
  qos : QoS
  message_id : Int?
  retain : Bool
  dup : Bool
} derive(Debug)

///|
pub(all) struct PacketId {
  message_id : Int
} derive(Debug)

///|
pub(all) struct SubscribeTopic {
  topic : String
  qos : QoS
} derive(Debug)

///|
pub(all) struct Subscribe {
  topics : Array[SubscribeTopic]
  message_id : Int
} derive(Debug)

///|
pub(all) enum SubackReturnCode {
  SuccessQoS0
  SuccessQoS1
  SuccessQoS2
  Failure
} derive(Eq, Debug)

///|
pub(all) struct Suback {
  message_id : Int
  return_codes : Array[SubackReturnCode]
} derive(Debug)

///|
pub(all) struct Unsubscribe {
  topics : Array[String]
  message_id : Int
} derive(Debug)

///|
pub(all) struct Unsuback {
  message_id : Int
} derive(Debug)

///|
pub(all) enum Packet {
  ConnectPacket(Connect)
  ConnackPacket(Connack)
  PublishPacket(Publish)
  PubackPacket(PacketId)
  PubrecPacket(PacketId)
  PubrelPacket(PacketId)
  PubcompPacket(PacketId)
  SubscribePacket(Subscribe)
  SubackPacket(Suback)
  UnsubscribePacket(Unsubscribe)
  UnsubackPacket(Unsuback)
  PingreqPacket
  PingrespPacket
  DisconnectPacket
} derive(Debug)

///|
fn append_all(out : Array[Byte], bytes : Array[Byte]) -> Unit {
  for b in bytes {
    out.push(b)
  }
}

///|
fn append_bytes(out : Array[Byte], bytes : Bytes) -> Unit {
  let arr = bytes.to_array()
  for b in arr {
    out.push(b)
  }
}

///|
fn slice_array(bytes : Array[Byte], start : Int, end : Int) -> Array[Byte] {
  let out : Array[Byte] = []
  let mut i = start
  while i < end {
    out.push(bytes[i])
    i = i + 1
  }
  out
}

///|
fn ensure_len(
  bytes : Array[Byte],
  offset : Int,
  len : Int,
  what : String,
) -> Result[Unit, String] {
  if offset < 0 {
    Err("\{what}: negative offset")
  } else if len < 0 {
    Err("\{what}: negative length")
  } else if offset + len > bytes.length() {
    Err("\{what}: truncated packet")
  } else {
    Ok(())
  }
}

///|
fn packet_body_bounds(
  bytes : Array[Byte],
  header : FixedHeader,
  what : String,
) -> Result[(Int, Int), String] {
  let body_start = header.header_len
  let body_end = body_start + header.remaining_length
  match ensure_len(bytes, body_start, header.remaining_length, what) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if body_end != bytes.length() {
    Err("\{what}: trailing bytes")
  } else {
    Ok((body_start, body_end))
  }
}

///|
fn ensure_fixed_header(
  header : FixedHeader,
  msg_type : MessageType,
  qos : QoS,
  retain : Bool,
  allow_dup : Bool,
  what : String,
) -> Result[Unit, String] {
  if header.message_type != msg_type {
    return Err("\{what}: invalid message type")
  }
  if header.qos != qos || header.retain != retain {
    return Err("\{what}: invalid fixed header flags")
  }
  if !allow_dup && header.dup {
    return Err("\{what}: invalid DUP flag")
  }
  Ok(())
}

///|
fn ensure_packet_id(id : Int, what : String) -> Result[Unit, String] {
  if id <= 0 || id > 65535 {
    Err("\{what} packet identifier must be 1..65535")
  } else {
    Ok(())
  }
}

///|
fn validate_mqtt_string(value : String, what : String) -> Result[Unit, String] {
  if value.contains_code_unit(0) {
    Err("\{what}: MQTT string must not contain U+0000")
  } else {
    Ok(())
  }
}

///|
fn validate_publish_topic(topic : String) -> Result[Unit, String] {
  if topic.is_empty() {
    Err("PUBLISH topic must not be empty")
  } else if topic.contains("#") || topic.contains("+") {
    Err("PUBLISH topic must not contain wildcard characters")
  } else {
    Ok(())
  }
}

///|
fn validate_topic_filter(topic : String, what : String) -> Result[Unit, String] {
  if topic.is_empty() {
    return Err("\{what} topic filter must not be empty")
  }
  let bytes = @utf8.encode(topic).to_array()
  let mut i = 0
  while i < bytes.length() {
    let b = bytes[i]
    if b == 0x23 {
      if i != bytes.length() - 1 {
        return Err("\{what} multi-level wildcard must be the last level")
      }
      if i > 0 && bytes[i - 1] != 0x2f {
        return Err("\{what} multi-level wildcard must occupy a whole level")
      }
    } else if b == 0x2b {
      if i > 0 && bytes[i - 1] != 0x2f {
        return Err("\{what} single-level wildcard must occupy a whole level")
      }
      if i + 1 < bytes.length() && bytes[i + 1] != 0x2f {
        return Err("\{what} single-level wildcard must occupy a whole level")
      }
    }
    i = i + 1
  }
  Ok(())
}

///|
fn qos_to_int(qos : QoS) -> Int {
  match qos {
    QoS0 => 0
    QoS1 => 1
    QoS2 => 2
  }
}

///|
fn int_to_qos(value : Int) -> Result[QoS, String] {
  match value {
    0 => Ok(QoS0)
    1 => Ok(QoS1)
    2 => Ok(QoS2)
    _ => Err("invalid QoS level")
  }
}

///|
fn message_type_to_int(msg_type : MessageType) -> Int {
  match msg_type {
    CONNECT => 1
    CONNACK => 2
    PUBLISH => 3
    PUBACK => 4
    PUBREC => 5
    PUBREL => 6
    PUBCOMP => 7
    SUBSCRIBE => 8
    SUBACK => 9
    UNSUBSCRIBE => 10
    UNSUBACK => 11
    PINGREQ => 12
    PINGRESP => 13
    DISCONNECT => 14
  }
}

///|
fn int_to_message_type(value : Int) -> Result[MessageType, String] {
  match value {
    1 => Ok(CONNECT)
    2 => Ok(CONNACK)
    3 => Ok(PUBLISH)
    4 => Ok(PUBACK)
    5 => Ok(PUBREC)
    6 => Ok(PUBREL)
    7 => Ok(PUBCOMP)
    8 => Ok(SUBSCRIBE)
    9 => Ok(SUBACK)
    10 => Ok(UNSUBSCRIBE)
    11 => Ok(UNSUBACK)
    12 => Ok(PINGREQ)
    13 => Ok(PINGRESP)
    14 => Ok(DISCONNECT)
    _ => Err("invalid MQTT message type")
  }
}

///|
fn fixed_header_byte(
  msg_type : MessageType,
  dup : Bool,
  qos : QoS,
  retain : Bool,
) -> Byte {
  let dup_bit = if dup { 0x08 } else { 0 }
  let retain_bit = if retain { 0x01 } else { 0 }
  (message_type_to_int(msg_type) * 16 +
  dup_bit +
  qos_to_int(qos) * 2 +
  retain_bit).to_byte()
}

///|
pub fn encode_remaining_length(length : Int) -> Result[Array[Byte], String] {
  if length < 0 || length > 268435455 {
    return Err("remaining length out of MQTT 3.1.1 range")
  }
  let out : Array[Byte] = []
  let mut x = length
  while true {
    let mut encoded : Byte = (x % 128).to_byte()
    x = x / 128
    if x > 0 {
      encoded = encoded | 0x80
    }
    out.push(encoded)
    if x == 0 {
      break
    }
  }
  Ok(out)
}

///|
pub fn decode_remaining_length(
  bytes : Array[Byte],
  offset : Int,
) -> Result[(Int, Int), String] {
  if offset < 0 || offset >= bytes.length() {
    return Err("remaining length: missing first byte")
  }
  let mut multiplier = 1
  let mut value = 0
  let mut index = offset
  let mut encoded_count = 0
  while true {
    if index >= bytes.length() {
      return Err("remaining length: truncated sequence")
    }
    let encoded = bytes[index]
    value = value + (encoded & 0x7F).to_int() * multiplier
    encoded_count = encoded_count + 1
    index = index + 1
    if encoded_count > 4 {
      return Err("remaining length: malformed sequence")
    }
    if (encoded & 0x80) == 0 {
      return Ok((value, index))
    }
    multiplier = multiplier * 128
  }
  Err("remaining length: malformed sequence")
}

///|
pub fn encode_string(value : String) -> Result[Array[Byte], String] {
  match validate_mqtt_string(value, "MQTT string") {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let bytes = @utf8.encode(value)
  let len = bytes.length()
  if len > 65535 {
    return Err("MQTT string exceeds 65535 bytes")
  }
  let out : Array[Byte] = []
  out.push(((len >> 8) & 0xFF).to_byte())
  out.push((len & 0xFF).to_byte())
  append_bytes(out, bytes)
  Ok(out)
}

///|
pub fn decode_string(
  bytes : Array[Byte],
  offset : Int,
) -> Result[(String, Int), String] {
  match ensure_len(bytes, offset, 2, "MQTT string length") {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let len = (bytes[offset].to_int() << 8) | bytes[offset + 1].to_int()
  let start = offset + 2
  match ensure_len(bytes, start, len, "MQTT string body") {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let raw = Bytes::from_array(slice_array(bytes, start, start + len))
  let decoded : Result[String, String] = try @utf8.decode(raw) |> Ok catch {
    Malformed(_) => Err("MQTT string body: invalid UTF-8")
  }
  match decoded {
    Ok(value) =>
      match validate_mqtt_string(value, "MQTT string body") {
        Err(e) => Err(e)
        Ok(_) => Ok((value, start + len))
      }
    Err(e) => Err(e)
  }
}

///|
pub fn encode_binary(value : Bytes) -> Result[Array[Byte], String] {
  let len = value.length()
  if len > 65535 {
    return Err("MQTT binary data exceeds 65535 bytes")
  }
  let out : Array[Byte] = []
  out.push(((len >> 8) & 0xFF).to_byte())
  out.push((len & 0xFF).to_byte())
  append_bytes(out, value)
  Ok(out)
}

///|
pub fn decode_binary(
  bytes : Array[Byte],
  offset : Int,
) -> Result[(Bytes, Int), String] {
  match ensure_len(bytes, offset, 2, "MQTT binary length") {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let len = (bytes[offset].to_int() << 8) | bytes[offset + 1].to_int()
  let start = offset + 2
  match ensure_len(bytes, start, len, "MQTT binary body") {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  Ok((Bytes::from_array(slice_array(bytes, start, start + len)), start + len))
}

///|
pub fn decode_fixed_header(bytes : Array[Byte]) -> Result[FixedHeader, String] {
  match ensure_len(bytes, 0, 2, "fixed header") {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let first = bytes[0]
  let type_id = (first / 16).to_int()
  let msg_type = match int_to_message_type(type_id) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let qos = match int_to_qos(((first / 2) & 0x03).to_int()) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let remaining = match decode_remaining_length(bytes, 1) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok({
    message_type: msg_type,
    dup: (first & 0x08) != 0,
    qos,
    retain: (first & 0x01) != 0,
    remaining_length: remaining.0,
    header_len: remaining.1,
  })
}

///|
pub fn packet_total_length(bytes : Array[Byte]) -> Result[Int, String] {
  let header = match decode_fixed_header(bytes) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let total = header.header_len + header.remaining_length
  if total > bytes.length() {
    Err("packet framing: incomplete packet")
  } else {
    Ok(total)
  }
}

///|
pub fn has_complete_packet(bytes : Array[Byte]) -> Bool {
  match packet_total_length(bytes) {
    Ok(_) => true
    Err(_) => false
  }
}

///|
fn append_fixed_header(
  packet : Array[Byte],
  msg_type : MessageType,
  dup : Bool,
  qos : QoS,
  retain : Bool,
  remaining_length : Int,
) -> Result[Unit, String] {
  packet.push(fixed_header_byte(msg_type, dup, qos, retain))
  match encode_remaining_length(remaining_length) {
    Ok(len_bytes) => {
      append_all(packet, len_bytes)
      Ok(())
    }
    Err(e) => Err(e)
  }
}

///|
fn validate_connect_flags(connect : Connect) -> Result[Unit, String] {
  if connect.flags.username != (connect.username is Some(_)) {
    return Err("CONNECT username flag does not match username field")
  }
  if connect.flags.password != (connect.password is Some(_)) {
    return Err("CONNECT password flag does not match password field")
  }
  if connect.flags.will_flag {
    if connect.will_topic is None || connect.will_message is None {
      return Err("CONNECT will flag requires will topic and will message")
    }
  } else {
    if connect.will_topic is Some(_) || connect.will_message is Some(_) {
      return Err("CONNECT will fields require will flag")
    }
    if connect.flags.will_retain || connect.flags.will_qos != QoS0 {
      return Err(
        "CONNECT will retain/QoS must be clear when will flag is false",
      )
    }
  }
  Ok(())
}

///|
pub fn encode_connect(connect : Connect) -> Result[Array[Byte], String] {
  if connect.keep_alive < 0 || connect.keep_alive > 65535 {
    return Err("CONNECT keep_alive must fit in 16 bits")
  }
  match validate_connect_flags(connect) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let body : Array[Byte] = []
  match encode_string("MQTT") {
    Ok(v) => append_all(body, v)
    Err(e) => return Err(e)
  }
  body.push(4)
  let mut flags : Byte = 0
  if connect.flags.username {
    flags = flags | 0x80
  }
  if connect.flags.password {
    flags = flags | 0x40
  }
  if connect.flags.will_retain {
    flags = flags | 0x20
  }
  flags = flags | (qos_to_int(connect.flags.will_qos) << 3).to_byte()
  if connect.flags.will_flag {
    flags = flags | 0x04
  }
  if connect.flags.clean_session {
    flags = flags | 0x02
  }
  body.push(flags)
  body.push(((connect.keep_alive >> 8) & 0xFF).to_byte())
  body.push((connect.keep_alive & 0xFF).to_byte())
  match encode_string(connect.client_id) {
    Ok(v) => append_all(body, v)
    Err(e) => return Err(e)
  }
  match connect.will_topic {
    Some(topic) =>
      match encode_string(topic) {
        Ok(v) => append_all(body, v)
        Err(e) => return Err(e)
      }
    None => ()
  }
  match connect.will_message {
    Some(message) =>
      match encode_binary(message) {
        Ok(v) => append_all(body, v)
        Err(e) => return Err(e)
      }
    None => ()
  }
  match connect.username {
    Some(username) =>
      match encode_string(username) {
        Ok(v) => append_all(body, v)
        Err(e) => return Err(e)
      }
    None => ()
  }
  match connect.password {
    Some(password) =>
      match encode_binary(password) {
        Ok(v) => append_all(body, v)
        Err(e) => return Err(e)
      }
    None => ()
  }
  let packet : Array[Byte] = []
  match
    append_fixed_header(packet, CONNECT, false, QoS0, false, body.length()) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  append_all(packet, body)
  Ok(packet)
}

///|
pub fn decode_connect(bytes : Array[Byte]) -> Result[Connect, String] {
  let header = match decode_fixed_header(bytes) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  match ensure_fixed_header(header, CONNECT, QoS0, false, false, "CONNECT") {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let bounds = match packet_body_bounds(bytes, header, "CONNECT body") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let body_start = bounds.0
  let body_end = bounds.1
  let protocol = match decode_string(bytes, body_start) {
    Ok(v) => v
    Err(e) => return Err("CONNECT protocol name: \{e}")
  }
  if protocol.0 != "MQTT" {
    return Err("CONNECT: protocol name must be MQTT")
  }
  let mut offset = protocol.1
  match ensure_len(bytes, offset, 4, "CONNECT variable header") {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if bytes[offset] != 4 {
    return Err("CONNECT: protocol level must be 4")
  }
  let flags_byte = bytes[offset + 1]
  if (flags_byte & 0x01) != 0 {
    return Err("CONNECT: reserved flag bit must be 0")
  }
  let will_qos_bits = ((flags_byte >> 3) & 0x03).to_int()
  if will_qos_bits == 3 {
    return Err("CONNECT: invalid will QoS")
  }
  let flags = {
    username: (flags_byte & 0x80) != 0,
    password: (flags_byte & 0x40) != 0,
    will_retain: (flags_byte & 0x20) != 0,
    will_qos: match int_to_qos(will_qos_bits) {
      Ok(v) => v
      Err(e) => return Err(e)
    },
    will_flag: (flags_byte & 0x04) != 0,
    clean_session: (flags_byte & 0x02) != 0,
  }
  if !flags.will_flag && (flags.will_retain || flags.will_qos != QoS0) {
    return Err("CONNECT: will retain/QoS set without will flag")
  }
  let keep_alive = (bytes[offset + 2].to_int() << 8) |
    bytes[offset + 3].to_int()
  offset = offset + 4
  let client_id = match decode_string(bytes, offset) {
    Ok(v) => {
      offset = v.1
      v.0
    }
    Err(e) => return Err("CONNECT client id: \{e}")
  }
  let will_topic = if flags.will_flag {
    match decode_string(bytes, offset) {
      Ok(v) => {
        offset = v.1
        Some(v.0)
      }
      Err(e) => return Err("CONNECT will topic: \{e}")
    }
  } else {
    None
  }
  let will_message = if flags.will_flag {
    match decode_binary(bytes, offset) {
      Ok(v) => {
        offset = v.1
        Some(v.0)
      }
      Err(e) => return Err("CONNECT will message: \{e}")
    }
  } else {
    None
  }
  let username = if flags.username {
    match decode_string(bytes, offset) {
      Ok(v) => {
        offset = v.1
        Some(v.0)
      }
      Err(e) => return Err("CONNECT username: \{e}")
    }
  } else {
    None
  }
  let password = if flags.password {
    match decode_binary(bytes, offset) {
      Ok(v) => {
        offset = v.1
        Some(v.0)
      }
      Err(e) => return Err("CONNECT password: \{e}")
    }
  } else {
    None
  }
  if offset != body_end {
    return Err("CONNECT: payload length mismatch")
  }
  Ok({
    client_id,
    username,
    password,
    will_topic,
    will_message,
    keep_alive,
    flags,
  })
}

///|
fn connack_code_to_byte(code : ConnackReturnCode) -> Byte {
  match code {
    ConnectionAccepted => 0
    UnacceptableProtocolVersion => 1
    IdentifierRejected => 2
    ServerUnavailable => 3
    BadUserNameOrPassword => 4
    NotAuthorized => 5
  }
}

///|
pub fn encode_connack(connack : Connack) -> Result[Array[Byte], String] {
  if connack.session_present && connack.return_code != ConnectionAccepted {
    return Err("CONNACK session_present requires accepted return code")
  }
  let flags : Byte = if connack.session_present { 0x01 } else { 0x00 }
  let body : Array[Byte] = [flags, connack_code_to_byte(connack.return_code)]
  let packet : Array[Byte] = []
  match
    append_fixed_header(packet, CONNACK, false, QoS0, false, body.length()) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  append_all(packet, body)
  Ok(packet)
}

///|
pub fn decode_connack(bytes : Array[Byte]) -> Result[Connack, String] {
  let header = match decode_fixed_header(bytes) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  match ensure_fixed_header(header, CONNACK, QoS0, false, false, "CONNACK") {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if header.remaining_length != 2 {
    return Err("CONNACK: invalid remaining length")
  }
  let bounds = match packet_body_bounds(bytes, header, "CONNACK body") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let ack_flags = bytes[bounds.0]
  if (ack_flags & 0xFE) != 0 {
    return Err("CONNACK: invalid acknowledge flags")
  }
  let return_code = match bytes[bounds.0 + 1] {
    0 => ConnectionAccepted
    1 => UnacceptableProtocolVersion
    2 => IdentifierRejected
    3 => ServerUnavailable
    4 => BadUserNameOrPassword
    5 => NotAuthorized
    _ => return Err("CONNACK: invalid return code")
  }
  if (ack_flags & 0x01) != 0 && return_code != ConnectionAccepted {
    return Err("CONNACK: session present requires accepted return code")
  }
  Ok({ session_present: (ack_flags & 0x01) != 0, return_code })
}

///|
pub fn encode_publish(publish : Publish) -> Result[Array[Byte], String] {
  match validate_publish_topic(publish.topic) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if publish.qos == QoS0 && publish.message_id is Some(_) {
    return Err("PUBLISH QoS0 must not include packet identifier")
  }
  if publish.qos != QoS0 && publish.message_id is None {
    return Err("PUBLISH QoS1/QoS2 requires packet identifier")
  }
  let body : Array[Byte] = []
  match encode_string(publish.topic) {
    Ok(v) => append_all(body, v)
    Err(e) => return Err(e)
  }
  match publish.message_id {
    Some(id) => {
      if id <= 0 || id > 65535 {
        return Err("PUBLISH packet identifier must be 1..65535")
      }
      body.push(((id >> 8) & 0xFF).to_byte())
      body.push((id & 0xFF).to_byte())
    }
    None => ()
  }
  append_bytes(body, publish.payload)
  let packet : Array[Byte] = []
  match
    append_fixed_header(
      packet,
      PUBLISH,
      publish.dup,
      publish.qos,
      publish.retain,
      body.length(),
    ) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  append_all(packet, body)
  Ok(packet)
}

///|
pub fn decode_publish(bytes : Array[Byte]) -> Result[Publish, String] {
  let header = match decode_fixed_header(bytes) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  if header.message_type != PUBLISH {
    return Err("PUBLISH: invalid fixed header type")
  }
  let bounds = match packet_body_bounds(bytes, header, "PUBLISH body") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let body_start = bounds.0
  let body_end = bounds.1
  let decoded_topic = match decode_string(bytes, body_start) {
    Ok(v) => v
    Err(e) => return Err("PUBLISH topic: \{e}")
  }
  let topic = decoded_topic.0
  match validate_publish_topic(topic) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let mut offset = decoded_topic.1
  let message_id = if header.qos != QoS0 {
    match ensure_len(bytes, offset, 2, "PUBLISH packet identifier") {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
    let id = (bytes[offset].to_int() << 8) | bytes[offset + 1].to_int()
    match ensure_packet_id(id, "PUBLISH") {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
    offset = offset + 2
    Some(id)
  } else {
    None
  }
  if offset > body_end {
    return Err("PUBLISH: body is shorter than variable header")
  }
  Ok({
    topic,
    payload: Bytes::from_array(slice_array(bytes, offset, body_end)),
    qos: header.qos,
    message_id,
    retain: header.retain,
    dup: header.dup,
  })
}

///|
fn encode_packet_id_only(
  msg_type : MessageType,
  id : Int,
  qos : QoS,
) -> Result[Array[Byte], String] {
  match ensure_packet_id(id, "packet identifier") {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let body : Array[Byte] = [((id >> 8) & 0xFF).to_byte(), (id & 0xFF).to_byte()]
  let packet : Array[Byte] = []
  match
    append_fixed_header(packet, msg_type, false, qos, false, body.length()) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  append_all(packet, body)
  Ok(packet)
}

///|
fn decode_packet_id_only(
  bytes : Array[Byte],
  msg_type : MessageType,
  qos : QoS,
  allow_dup : Bool,
  what : String,
) -> Result[PacketId, String] {
  let header = match decode_fixed_header(bytes) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  match ensure_fixed_header(header, msg_type, qos, false, allow_dup, what) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if header.remaining_length != 2 {
    return Err("\{what}: invalid remaining length")
  }
  let bounds = match packet_body_bounds(bytes, header, "\{what} body") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let id = (bytes[bounds.0].to_int() << 8) | bytes[bounds.0 + 1].to_int()
  match ensure_packet_id(id, what) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  Ok({ message_id: id })
}

///|
pub fn encode_puback(message_id : Int) -> Result[Array[Byte], String] {
  encode_packet_id_only(PUBACK, message_id, QoS0)
}

///|
pub fn decode_puback(bytes : Array[Byte]) -> Result[PacketId, String] {
  decode_packet_id_only(bytes, PUBACK, QoS0, false, "PUBACK")
}

///|
pub fn encode_pubrec(message_id : Int) -> Result[Array[Byte], String] {
  encode_packet_id_only(PUBREC, message_id, QoS0)
}

///|
pub fn decode_pubrec(bytes : Array[Byte]) -> Result[PacketId, String] {
  decode_packet_id_only(bytes, PUBREC, QoS0, false, "PUBREC")
}

///|
pub fn encode_pubrel(message_id : Int) -> Result[Array[Byte], String] {
  encode_packet_id_only(PUBREL, message_id, QoS1)
}

///|
pub fn decode_pubrel(bytes : Array[Byte]) -> Result[PacketId, String] {
  decode_packet_id_only(bytes, PUBREL, QoS1, true, "PUBREL")
}

///|
pub fn encode_pubcomp(message_id : Int) -> Result[Array[Byte], String] {
  encode_packet_id_only(PUBCOMP, message_id, QoS0)
}

///|
pub fn decode_pubcomp(bytes : Array[Byte]) -> Result[PacketId, String] {
  decode_packet_id_only(bytes, PUBCOMP, QoS0, false, "PUBCOMP")
}

///|
pub fn encode_subscribe(subscribe : Subscribe) -> Result[Array[Byte], String] {
  if subscribe.message_id <= 0 || subscribe.message_id > 65535 {
    return Err("SUBSCRIBE packet identifier must be 1..65535")
  }
  if subscribe.topics.length() == 0 {
    return Err("SUBSCRIBE requires at least one topic")
  }
  let body : Array[Byte] = []
  body.push(((subscribe.message_id >> 8) & 0xFF).to_byte())
  body.push((subscribe.message_id & 0xFF).to_byte())
  for topic in subscribe.topics {
    match validate_topic_filter(topic.topic, "SUBSCRIBE") {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
    match encode_string(topic.topic) {
      Ok(v) => append_all(body, v)
      Err(e) => return Err(e)
    }
    body.push(qos_to_int(topic.qos).to_byte())
  }
  let packet : Array[Byte] = []
  match
    append_fixed_header(packet, SUBSCRIBE, false, QoS1, false, body.length()) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  append_all(packet, body)
  Ok(packet)
}

///|
pub fn decode_subscribe(bytes : Array[Byte]) -> Result[Subscribe, String] {
  let header = match decode_fixed_header(bytes) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  match ensure_fixed_header(header, SUBSCRIBE, QoS1, false, true, "SUBSCRIBE") {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if header.remaining_length < 5 {
    return Err("SUBSCRIBE: invalid remaining length")
  }
  let bounds = match packet_body_bounds(bytes, header, "SUBSCRIBE body") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let mut offset = bounds.0
  let body_end = bounds.1
  let id = (bytes[offset].to_int() << 8) | bytes[offset + 1].to_int()
  match ensure_packet_id(id, "SUBSCRIBE") {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  offset = offset + 2
  let topics : Array[SubscribeTopic] = []
  while offset < body_end {
    let decoded_topic = match decode_string(bytes, offset) {
      Ok(v) => v
      Err(e) => return Err("SUBSCRIBE topic: \{e}")
    }
    offset = decoded_topic.1
    match ensure_len(bytes, offset, 1, "SUBSCRIBE requested QoS") {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
    let qos = match int_to_qos(bytes[offset].to_int()) {
      Ok(v) => v
      Err(_) => return Err("SUBSCRIBE: invalid requested QoS")
    }
    match validate_topic_filter(decoded_topic.0, "SUBSCRIBE") {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
    topics.push({ topic: decoded_topic.0, qos })
    offset = offset + 1
  }
  if topics.length() == 0 {
    return Err("SUBSCRIBE requires at least one topic")
  }
  Ok({ topics, message_id: id })
}

///|
fn suback_code_to_byte(code : SubackReturnCode) -> Byte {
  match code {
    SuccessQoS0 => 0
    SuccessQoS1 => 1
    SuccessQoS2 => 2
    Failure => 128
  }
}

///|
pub fn encode_suback(suback : Suback) -> Result[Array[Byte], String] {
  match ensure_packet_id(suback.message_id, "SUBACK") {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if suback.return_codes.length() == 0 {
    return Err("SUBACK requires at least one return code")
  }
  let body : Array[Byte] = [
    ((suback.message_id >> 8) & 0xFF).to_byte(),
    (suback.message_id & 0xFF).to_byte(),
  ]
  for code in suback.return_codes {
    body.push(suback_code_to_byte(code))
  }
  let packet : Array[Byte] = []
  match append_fixed_header(packet, SUBACK, false, QoS0, false, body.length()) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  append_all(packet, body)
  Ok(packet)
}

///|
pub fn decode_suback(bytes : Array[Byte]) -> Result[Suback, String] {
  let header = match decode_fixed_header(bytes) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  match ensure_fixed_header(header, SUBACK, QoS0, false, false, "SUBACK") {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if header.remaining_length < 3 {
    return Err("SUBACK: invalid remaining length")
  }
  let bounds = match packet_body_bounds(bytes, header, "SUBACK body") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let body_start = bounds.0
  let id = (bytes[body_start].to_int() << 8) | bytes[body_start + 1].to_int()
  match ensure_packet_id(id, "SUBACK") {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let codes : Array[SubackReturnCode] = []
  let mut i = body_start + 2
  let body_end = bounds.1
  while i < body_end {
    let code = match bytes[i] {
      0 => SuccessQoS0
      1 => SuccessQoS1
      2 => SuccessQoS2
      128 => Failure
      _ => return Err("SUBACK: invalid return code")
    }
    codes.push(code)
    i = i + 1
  }
  Ok({ message_id: id, return_codes: codes })
}

///|
pub fn encode_unsubscribe(
  unsubscribe : Unsubscribe,
) -> Result[Array[Byte], String] {
  if unsubscribe.message_id <= 0 || unsubscribe.message_id > 65535 {
    return Err("UNSUBSCRIBE packet identifier must be 1..65535")
  }
  if unsubscribe.topics.length() == 0 {
    return Err("UNSUBSCRIBE requires at least one topic")
  }
  let body : Array[Byte] = []
  body.push(((unsubscribe.message_id >> 8) & 0xFF).to_byte())
  body.push((unsubscribe.message_id & 0xFF).to_byte())
  for topic in unsubscribe.topics {
    match validate_topic_filter(topic, "UNSUBSCRIBE") {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
    match encode_string(topic) {
      Ok(v) => append_all(body, v)
      Err(e) => return Err(e)
    }
  }
  let packet : Array[Byte] = []
  match
    append_fixed_header(packet, UNSUBSCRIBE, false, QoS1, false, body.length()) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  append_all(packet, body)
  Ok(packet)
}

///|
pub fn decode_unsubscribe(bytes : Array[Byte]) -> Result[Unsubscribe, String] {
  let header = match decode_fixed_header(bytes) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  match
    ensure_fixed_header(header, UNSUBSCRIBE, QoS1, false, true, "UNSUBSCRIBE") {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if header.remaining_length < 5 {
    return Err("UNSUBSCRIBE: invalid remaining length")
  }
  let bounds = match packet_body_bounds(bytes, header, "UNSUBSCRIBE body") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let mut offset = bounds.0
  let body_end = bounds.1
  let id = (bytes[offset].to_int() << 8) | bytes[offset + 1].to_int()
  match ensure_packet_id(id, "UNSUBSCRIBE") {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  offset = offset + 2
  let topics : Array[String] = []
  while offset < body_end {
    let decoded_topic = match decode_string(bytes, offset) {
      Ok(v) => v
      Err(e) => return Err("UNSUBSCRIBE topic: \{e}")
    }
    match validate_topic_filter(decoded_topic.0, "UNSUBSCRIBE") {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
    topics.push(decoded_topic.0)
    offset = decoded_topic.1
  }
  if topics.length() == 0 {
    return Err("UNSUBSCRIBE requires at least one topic")
  }
  Ok({ topics, message_id: id })
}

///|
pub fn encode_unsuback(message_id : Int) -> Result[Array[Byte], String] {
  encode_packet_id_only(UNSUBACK, message_id, QoS0)
}

///|
pub fn decode_unsuback(bytes : Array[Byte]) -> Result[Unsuback, String] {
  let id = match
    decode_packet_id_only(bytes, UNSUBACK, QoS0, false, "UNSUBACK") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok({ message_id: id.message_id })
}

///|
fn encode_empty_packet(msg_type : MessageType) -> Result[Array[Byte], String] {
  let packet : Array[Byte] = []
  match append_fixed_header(packet, msg_type, false, QoS0, false, 0) {
    Err(e) => Err(e)
    Ok(_) => Ok(packet)
  }
}

///|
fn decode_empty_packet(
  bytes : Array[Byte],
  msg_type : MessageType,
  what : String,
) -> Result[Unit, String] {
  let header = match decode_fixed_header(bytes) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  match ensure_fixed_header(header, msg_type, QoS0, false, false, what) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if header.remaining_length != 0 {
    return Err("\{what}: remaining length must be 0")
  }
  match packet_body_bounds(bytes, header, "\{what} body") {
    Err(e) => Err(e)
    Ok(_) => Ok(())
  }
}

///|
pub fn encode_pingreq() -> Result[Array[Byte], String] {
  encode_empty_packet(PINGREQ)
}

///|
pub fn decode_pingreq(bytes : Array[Byte]) -> Result[Unit, String] {
  decode_empty_packet(bytes, PINGREQ, "PINGREQ")
}

///|
pub fn encode_pingresp() -> Result[Array[Byte], String] {
  encode_empty_packet(PINGRESP)
}

///|
pub fn decode_pingresp(bytes : Array[Byte]) -> Result[Unit, String] {
  decode_empty_packet(bytes, PINGRESP, "PINGRESP")
}

///|
pub fn encode_disconnect() -> Result[Array[Byte], String] {
  encode_empty_packet(DISCONNECT)
}

///|
pub fn decode_disconnect(bytes : Array[Byte]) -> Result[Unit, String] {
  decode_empty_packet(bytes, DISCONNECT, "DISCONNECT")
}

///|
pub fn decode_packet(bytes : Array[Byte]) -> Result[Packet, String] {
  let header = match decode_fixed_header(bytes) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  match header.message_type {
    CONNECT =>
      match decode_connect(bytes) {
        Ok(v) => Ok(ConnectPacket(v))
        Err(e) => Err(e)
      }
    CONNACK =>
      match decode_connack(bytes) {
        Ok(v) => Ok(ConnackPacket(v))
        Err(e) => Err(e)
      }
    PUBLISH =>
      match decode_publish(bytes) {
        Ok(v) => Ok(PublishPacket(v))
        Err(e) => Err(e)
      }
    PUBACK =>
      match decode_puback(bytes) {
        Ok(v) => Ok(PubackPacket(v))
        Err(e) => Err(e)
      }
    PUBREC =>
      match decode_pubrec(bytes) {
        Ok(v) => Ok(PubrecPacket(v))
        Err(e) => Err(e)
      }
    PUBREL =>
      match decode_pubrel(bytes) {
        Ok(v) => Ok(PubrelPacket(v))
        Err(e) => Err(e)
      }
    PUBCOMP =>
      match decode_pubcomp(bytes) {
        Ok(v) => Ok(PubcompPacket(v))
        Err(e) => Err(e)
      }
    SUBSCRIBE =>
      match decode_subscribe(bytes) {
        Ok(v) => Ok(SubscribePacket(v))
        Err(e) => Err(e)
      }
    SUBACK =>
      match decode_suback(bytes) {
        Ok(v) => Ok(SubackPacket(v))
        Err(e) => Err(e)
      }
    UNSUBSCRIBE =>
      match decode_unsubscribe(bytes) {
        Ok(v) => Ok(UnsubscribePacket(v))
        Err(e) => Err(e)
      }
    UNSUBACK =>
      match decode_unsuback(bytes) {
        Ok(v) => Ok(UnsubackPacket(v))
        Err(e) => Err(e)
      }
    PINGREQ =>
      match decode_pingreq(bytes) {
        Ok(_) => Ok(PingreqPacket)
        Err(e) => Err(e)
      }
    PINGRESP =>
      match decode_pingresp(bytes) {
        Ok(_) => Ok(PingrespPacket)
        Err(e) => Err(e)
      }
    DISCONNECT =>
      match decode_disconnect(bytes) {
        Ok(_) => Ok(DisconnectPacket)
        Err(e) => Err(e)
      }
  }
}

///|
pub fn is_pingresp(bytes : Array[Byte]) -> Bool {
  bytes.length() == 2 &&
  bytes[0] == fixed_header_byte(PINGRESP, false, QoS0, false) &&
  bytes[1] == 0
}
