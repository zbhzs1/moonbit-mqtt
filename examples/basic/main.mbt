///|
fn main {
  let encoded = @mqtt.encode_publish({
    topic: "sensor/temp",
    payload: b"24.5",
    qos: @mqtt.QoS1,
    message_id: Some(7),
    retain: false,
    dup: false,
  })
  match encoded {
    Err(message) => println(message)
    Ok(packet) =>
      match @mqtt.decode_publish(packet) {
        Err(message) => println(message)
        Ok(decoded) => {
          println(decoded.topic)
          println(decoded.payload.to_string())
        }
      }
  }
}
