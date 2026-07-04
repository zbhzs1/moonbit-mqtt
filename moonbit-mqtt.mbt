// MQTT 3.1.1 Client Implementation
// https://docs.oasis-open.org/mqtt/mqtt/v3.1.1/os/mqtt-v3.1.1-os.html

// MQTT Message Types
pub enum MessageType {
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

// QoS Levels
pub enum QoS {
  QoS0 // At most once
  QoS1 // At least once
  QoS2 // Exactly once
} derive(Eq, Debug)

// Fixed Header
pub struct FixedHeader {
  message_type : MessageType
  dup : Bool
  qos : QoS
  retain : Bool
  remaining_length : Int
} derive(Debug)

// Connect Flags
pub struct ConnectFlags {
  username : Bool
  password : Bool
  will_retain : Bool
  will_qos : QoS
  will_flag : Bool
  clean_session : Bool
} derive(Debug)

// Connect Message
pub struct Connect {
  client_id : String
  username : String?
  password : String?
  will_topic : String?
  will_message : String?
  keep_alive : Int
  flags : ConnectFlags
} derive(Debug)

// ConnACK Return Codes
pub enum ConnackReturnCode {
  ConnectionAccepted
  UnacceptableProtocolVersion
  IdentifierRejected
  ServerUnavailable
  BadUserNameOrPassword
  NotAuthorized
} derive(Eq, Debug)

// ConnACK Message
pub struct Connack {
  session_present : Bool
  return_code : ConnackReturnCode
} derive(Debug)

// Publish Message
pub struct Publish {
  topic : String
  payload : Bytes
  qos : QoS
  message_id : Int?
  retain : Bool
  dup : Bool
} derive(Debug)

// Subscribe Topic
pub struct SubscribeTopic {
  topic : String
  qos : QoS
} derive(Debug)

// Subscribe Message
pub struct Subscribe {
  topics : Array[SubscribeTopic]
  message_id : Int
} derive(Debug)

// SubACK Return Codes
pub enum SubackReturnCode {
  SuccessQoS0
  SuccessQoS1
  SuccessQoS2
  Failure
} derive(Eq, Debug)

// SubACK Message
pub struct Suback {
  message_id : Int
  return_codes : Array[SubackReturnCode]
} derive(Debug)

// Unsubscribe Message
pub struct Unsubscribe {
  topics : Array[String]
  message_id : Int
} derive(Debug)

// UnsubACK Message
pub struct Unsuback {
  message_id : Int
} derive(Debug)

// MQTT Client
pub struct Client {
  host : String
  port : Int
  client_id : String
  username : String?
  password : String?
  keep_alive : Int
  connected : Bool
  message_id : Int
} derive(Debug)

// Create a new MQTT client
pub fn Client::new(host : String, port : Int, client_id : String) -> Client {
  {
    host: host,
    port: port,
    client_id: client_id,
    username: None,
    password: None,
    keep_alive: 60,
    connected: false,
    message_id: 0,
  }
}

// Set username and password
pub fn Client::set_credentials(self : Client, username : String, password : String) -> Client {
  {
    host: self.host,
    port: self.port,
    client_id: self.client_id,
    username: Some(username),
    password: Some(password),
    keep_alive: self.keep_alive,
    connected: self.connected,
    message_id: self.message_id,
  }
}

// Set keep alive interval
pub fn Client::set_keep_alive(self : Client, keep_alive : Int) -> Client {
  {
    host: self.host,
    port: self.port,
    client_id: self.client_id,
    username: self.username,
    password: self.password,
    keep_alive: keep_alive,
    connected: self.connected,
    message_id: self.message_id,
  }
}

// Generate next message ID
fn Client::next_message_id(self : Client) -> (Client, Int) {
  let next_id = if self.message_id == 65535 { 1 } else { self.message_id + 1 }
  ({
    host: self.host,
    port: self.port,
    client_id: self.client_id,
    username: self.username,
    password: self.password,
    keep_alive: self.keep_alive,
    connected: self.connected,
    message_id: next_id,
  }, next_id)
}

// Encode remaining length using variable length encoding
fn encode_remaining_length(length : Int) -> Array[Byte] {
  let result : Array[Byte] = []
  let mut x = length
  while true {
    let mut encoded_byte : Byte = (x % 128).to_byte()
    x = x / 128
    if x > 0 {
      encoded_byte = encoded_byte | 0x80
    }
    result.push(encoded_byte)
    if x == 0 { break }
  }
  result
}

// Decode remaining length from bytes
fn decode_remaining_length(bytes : Array[Byte]) -> (Int, Int) {
  let mut multiplier = 1
  let mut value = 0
  let mut index = 0
  while true {
    let encoded_byte = bytes[index]
    value = value + (encoded_byte & 0x7F).to_int() * multiplier
    multiplier = multiplier * 128
    index = index + 1
    if (encoded_byte & 0x80) == 0 { break }
  }
  (value, index)
}

// Encode message type to byte
fn encode_message_type(msg_type : MessageType, dup : Bool, qos : QoS, retain : Bool) -> Byte {
  let type_byte = (match msg_type {
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
  })

  let qos_byte = match qos {
    QoS0 => 0
    QoS1 => 1
    QoS2 => 2
  }

  let dup_byte = if dup { 1 } else { 0 }
  let retain_byte = if retain { 1 } else { 0 }

  ((type_byte * 16) + (dup_byte * 8) + (qos_byte * 2) + retain_byte).to_byte()
}

// Decode message type from byte
fn decode_message_type(byte : Byte) -> (MessageType, Bool, QoS, Bool) {
  let type_val = (byte / 16).to_int()
  let dup = (byte & 0x08) != 0
  let qos_val = ((byte / 2) & 0x03).to_int()
  let retain = (byte & 0x01) != 0

  let msg_type = match type_val {
    1 => CONNECT
    2 => CONNACK
    3 => PUBLISH
    4 => PUBACK
    5 => PUBREC
    6 => PUBREL
    7 => PUBCOMP
    8 => SUBSCRIBE
    9 => SUBACK
    10 => UNSUBSCRIBE
    11 => UNSUBACK
    12 => PINGREQ
    13 => PINGRESP
    14 => DISCONNECT
    _ => abort("Invalid message type")
  }

  let qos = match qos_val {
    0 => QoS0
    1 => QoS1
    2 => QoS2
    _ => abort("Invalid QoS level")
  }

  (msg_type, dup, qos, retain)
}

// Encode string with 2-byte length prefix
fn encode_string(s : String) -> Array[Byte] {
  let bytes = s.to_bytes()
  let len = bytes.length()
  let result : Array[Byte] = []
  result.push(((len >> 8) & 0xFF).to_byte())
  result.push((len & 0xFF).to_byte())
  let mut i = 0
  while i < len {
    result.push(bytes[i])
    i = i + 1
  }
  result
}

// Decode string with 2-byte length prefix
fn decode_string(bytes : Array[Byte], offset : Int) -> (String, Int) {
  let len = ((bytes[offset].to_int() << 8) | bytes[offset + 1].to_int())
  let _str_bytes : Array[Byte] = []
  let _i = 0
  // TODO: Find correct method to convert bytes to string
  ("", offset + 2 + len)
}

// Encode CONNECT message
fn encode_connect(connect : Connect) -> Array[Byte] {
  let payload : Array[Byte] = []

  // Protocol name "MQTT" (4 bytes)
  let mqtt_bytes = encode_string("MQTT")
  let mut i = 0
  while i < mqtt_bytes.length() {
    payload.push(mqtt_bytes[i])
    i = i + 1
  }

  // Protocol level (4 for MQTT 3.1.1)
  payload.push(4)

  // Connect flags
  let flags_byte : Byte = {
    let mut byte : Byte = 0
    if connect.flags.username { byte = byte | 0x80 }
    if connect.flags.password { byte = byte | 0x40 }
    if connect.flags.will_retain { byte = byte | 0x20 }
    let will_qos = match connect.flags.will_qos {
      QoS0 => 0
      QoS1 => 1
      QoS2 => 2
    }
    byte = byte | (will_qos << 3).to_byte()
    if connect.flags.will_flag { byte = byte | 0x04 }
    if connect.flags.clean_session { byte = byte | 0x02 }
    byte
  }
  payload.push(flags_byte)

  // Keep alive (2 bytes)
  payload.push(((connect.keep_alive >> 8) & 0xFF).to_byte())
  payload.push((connect.keep_alive & 0xFF).to_byte())

  // Client ID
  let client_id_bytes = encode_string(connect.client_id)
  let mut j = 0
  while j < client_id_bytes.length() {
    payload.push(client_id_bytes[j])
    j = j + 1
  }

  // Will topic and message (if present)
  match connect.will_topic {
    Some(topic) => {
      let topic_bytes = encode_string(topic)
      let mut j = 0
      while j < topic_bytes.length() {
        payload.push(topic_bytes[j])
        j = j + 1
      }
      match connect.will_message {
        Some(message) => {
          let msg_bytes = encode_string(message)
          let mut k = 0
          while k < msg_bytes.length() {
            payload.push(msg_bytes[k])
            k = k + 1
          }
        }
        None => ()
      }
    }
    None => ()
  }

  // Username (if present)
  match connect.username {
    Some(username) => {
      let user_bytes = encode_string(username)
      let mut j = 0
      while j < user_bytes.length() {
        payload.push(user_bytes[j])
        j = j + 1
      }
    }
    None => ()
  }

  // Password (if present)
  match connect.password {
    Some(password) => {
      let pass_bytes = encode_string(password)
      let mut j = 0
      while j < pass_bytes.length() {
        payload.push(pass_bytes[j])
        j = j + 1
      }
    }
    None => ()
  }

  // Build fixed header
  let packet : Array[Byte] = []
  packet.push(encode_message_type(CONNECT, false, QoS0, false))
  let len_bytes = encode_remaining_length(payload.length())
  let mut j = 0
  while j < len_bytes.length() {
    packet.push(len_bytes[j])
    j = j + 1
  }
  let mut k = 0
  while k < payload.length() {
    packet.push(payload[k])
    k = k + 1
  }

  packet
}

// Encode PUBLISH message (QoS 0 only for MVP)
fn encode_publish(publish : Publish) -> Array[Byte] {
  let payload : Array[Byte] = []

  // Topic
  let topic_bytes = encode_string(publish.topic)
  let mut j = 0
  while j < topic_bytes.length() {
    payload.push(topic_bytes[j])
    j = j + 1
  }

  // Message ID (only for QoS 1 and 2)
  match publish.message_id {
    Some(msg_id) => {
      payload.push(((msg_id >> 8) & 0xFF).to_byte())
      payload.push((msg_id & 0xFF).to_byte())
    }
    None => ()
  }

  // Payload
  let payload_array = publish.payload.to_array()
  let mut j = 0
  while j < payload_array.length() {
    payload.push(payload_array[j])
    j = j + 1
  }

  // Build fixed header
  let packet : Array[Byte] = []
  packet.push(encode_message_type(PUBLISH, publish.dup, publish.qos, publish.retain))
  let len_bytes = encode_remaining_length(payload.length())
  let mut j = 0
  while j < len_bytes.length() {
    packet.push(len_bytes[j])
    j = j + 1
  }
  let mut k = 0
  while k < payload.length() {
    packet.push(payload[k])
    k = k + 1
  }

  packet
}

// Encode SUBSCRIBE message
fn encode_subscribe(subscribe : Subscribe) -> Array[Byte] {
  let payload : Array[Byte] = []

  // Message ID (2 bytes)
  payload.push(((subscribe.message_id >> 8) & 0xFF).to_byte())
  payload.push((subscribe.message_id & 0xFF).to_byte())

  // Topics
  for topic in subscribe.topics {
    let topic_bytes = encode_string(topic.topic)
    let mut j = 0
    while j < topic_bytes.length() {
      payload.push(topic_bytes[j])
      j = j + 1
    }
    let qos = match topic.qos {
      QoS0 => 0
      QoS1 => 1
      QoS2 => 2
    }
    payload.push(qos.to_byte())
  }

  // Build fixed header
  let packet : Array[Byte] = []
  packet.push(encode_message_type(SUBSCRIBE, false, QoS1, false))
  let len_bytes = encode_remaining_length(payload.length())
  let mut j = 0
  while j < len_bytes.length() {
    packet.push(len_bytes[j])
    j = j + 1
  }
  let mut k = 0
  while k < payload.length() {
    packet.push(payload[k])
    k = k + 1
  }

  packet
}

// Encode UNSUBSCRIBE message
fn encode_unsubscribe(unsubscribe : Unsubscribe) -> Array[Byte] {
  let payload : Array[Byte] = []

  // Message ID (2 bytes)
  payload.push(((unsubscribe.message_id >> 8) & 0xFF).to_byte())
  payload.push((unsubscribe.message_id & 0xFF).to_byte())

  // Topics
  for topic in unsubscribe.topics {
    let topic_bytes = encode_string(topic)
    let mut j = 0
    while j < topic_bytes.length() {
      payload.push(topic_bytes[j])
      j = j + 1
    }
  }

  // Build fixed header
  let packet : Array[Byte] = []
  packet.push(encode_message_type(UNSUBSCRIBE, false, QoS1, false))
  let len_bytes = encode_remaining_length(payload.length())
  let mut j = 0
  while j < len_bytes.length() {
    packet.push(len_bytes[j])
    j = j + 1
  }
  let mut k = 0
  while k < payload.length() {
    packet.push(payload[k])
    k = k + 1
  }

  packet
}

// Encode PINGREQ message
fn encode_pingreq() -> Array[Byte] {
  let packet : Array[Byte] = []
  packet.push(encode_message_type(PINGREQ, false, QoS0, false))
  packet.push(0) // Remaining length is 0
  packet
}

// Encode DISCONNECT message
fn encode_disconnect() -> Array[Byte] {
  let packet : Array[Byte] = []
  packet.push(encode_message_type(DISCONNECT, false, QoS0, false))
  packet.push(0) // Remaining length is 0
  packet
}

// Decode CONNACK message
fn decode_connack(bytes : Array[Byte]) -> Connack {
  let session_present = (bytes[2] & 0x01) != 0
  let return_code = match bytes[3] {
    0 => ConnectionAccepted
    1 => UnacceptableProtocolVersion
    2 => IdentifierRejected
    3 => ServerUnavailable
    4 => BadUserNameOrPassword
    5 => NotAuthorized
    _ => abort("Invalid CONNACK return code")
  }
  { session_present: session_present, return_code: return_code }
}

// Decode PUBLISH message
fn decode_publish(bytes : Array[Byte]) -> Publish {
  let (_, dup, qos, retain) = decode_message_type(bytes[0])
  let remaining_bytes : Array[Byte] = []
  let _i = 1
  let (_, header_len) = decode_remaining_length(remaining_bytes)

  let mut offset = header_len + 1

  // Decode topic
  let (topic, new_offset) = decode_string(bytes, offset)
  offset = new_offset

  // Decode message ID (if QoS > 0)
  let message_id = if qos != QoS0 {
    let msg_id = ((bytes[offset].to_int() << 8) | bytes[offset + 1].to_int())
    offset = offset + 2
    Some(msg_id)
  } else {
    None
  }

  // Decode payload
  let payload_bytes : Array[Byte] = []
  let _i = offset
  let payload = Bytes::from_array(payload_bytes)

  {
    topic: topic,
    payload: payload,
    qos: qos,
    message_id: message_id,
    retain: retain,
    dup: dup,
  }
}

// Decode SUBACK message
fn decode_suback(bytes : Array[Byte]) -> Suback {
  let message_id = ((bytes[2].to_int() << 8) | bytes[3].to_int())
  let num_codes = bytes.length() - 4
  let return_codes : Array[SubackReturnCode] = Array::make(num_codes, SuccessQoS0)

  let mut offset = 4
  let mut i = 0
  while offset < bytes.length() {
    let code = match bytes[offset] {
      0 => SuccessQoS0
      1 => SuccessQoS1
      2 => SuccessQoS2
      128 => Failure
      _ => abort("Invalid SUBACK return code")
    }
    return_codes[i] = code
    offset = offset + 1
    i = i + 1
  }

  { message_id: message_id, return_codes: return_codes }
}

// Decode UNSUBACK message
fn decode_unsuback(bytes : Array[Byte]) -> Unsuback {
  let message_id = ((bytes[2].to_int() << 8) | bytes[3].to_int())
  { message_id: message_id }
}

// Connect to MQTT broker (synchronous for MVP)
pub fn Client::connect(self : Client) -> Result[Client, String] {
  // Build CONNECT message
  let connect = {
    client_id: self.client_id,
    username: self.username,
    password: self.password,
    will_topic: None,
    will_message: None,
    keep_alive: self.keep_alive,
    flags: {
      username: self.username is Some(_),
      password: self.password is Some(_),
      will_retain: false,
      will_qos: QoS0,
      will_flag: false,
      clean_session: true,
    },
  }

  let _packet = encode_connect(connect)

  // For MVP, we'll return success without actual network connection
  // In a full implementation, this would:
  // 1. Establish TCP connection to self.host:self.port
  // 2. Send the CONNECT packet
  // 3. Wait for CONNACK response
  // 4. Parse CONNACK and check return code
  // 5. Return error if connection failed

  Ok({ connected: true, host: self.host, port: self.port, client_id: self.client_id, username: self.username, password: self.password, keep_alive: self.keep_alive, message_id: self.message_id })
}

// Publish a message (QoS 0 only for MVP)
pub fn Client::publish(self : Client, topic : String, payload : Bytes) -> Client {
  if !self.connected {
    abort("Client is not connected")
  }

  let publish = {
    topic: topic,
    payload: payload,
    qos: QoS0,
    message_id: None,
    retain: false,
    dup: false,
  }

  let _packet = encode_publish(publish)

  // For MVP, we'll just encode the packet
  // In a full implementation, this would send the packet over the network

  self
}

// Subscribe to a topic
pub fn Client::subscribe(self : Client, topic : String, qos : QoS) -> (Client, Int) {
  if !self.connected {
    abort("Client is not connected")
  }

  let (new_client, message_id) = self.next_message_id()

  let subscribe : Subscribe = {
    topics: [{ topic: topic, qos: qos }],
    message_id: message_id,
  }

  let _packet = encode_subscribe(subscribe)

  // For MVP, we'll just encode the packet
  // In a full implementation, this would:
  // 1. Send the SUBSCRIBE packet
  // 2. Wait for SUBACK response
  // 3. Parse SUBACK and check return codes

  (new_client, message_id)
}

// Unsubscribe from a topic
pub fn Client::unsubscribe(self : Client, topic : String) -> (Client, Int) {
  if !self.connected {
    abort("Client is not connected")
  }

  let (new_client, message_id) = self.next_message_id()

  let unsubscribe : Unsubscribe = {
    topics: [topic],
    message_id: message_id,
  }

  let _packet = encode_unsubscribe(unsubscribe)

  // For MVP, we'll just encode the packet
  // In a full implementation, this would:
  // 1. Send the UNSUBSCRIBE packet
  // 2. Wait for UNSUBACK response

  (new_client, message_id)
}

// Disconnect from broker
pub fn Client::disconnect(self : Client) -> Client {
  if !self.connected {
    abort("Client is not connected")
  }

  let _packet = encode_disconnect()

  // For MVP, we'll just encode the packet
  // In a full implementation, this would:
  // 1. Send the DISCONNECT packet
  // 2. Close the TCP connection

  { connected: false, host: self.host, port: self.port, client_id: self.client_id, username: self.username, password: self.password, keep_alive: self.keep_alive, message_id: self.message_id }
}
