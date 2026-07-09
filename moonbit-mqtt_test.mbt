///|
fn[T] expect_ok(result : Result[T, String]) -> T {
  match result {
    Ok(value) => value
    Err(message) => abort(message)
  }
}

///|
fn[T] expect_err(result : Result[T, String]) -> String {
  match result {
    Ok(_) => abort("expected Err")
    Err(message) => message
  }
}

///|
test "remaining length codec covers MQTT variable length examples" {
  assert_true(expect_ok(encode_remaining_length(0)) == [0])
  assert_true(expect_ok(encode_remaining_length(127)) == [127])
  assert_true(expect_ok(encode_remaining_length(128)) == [128, 1])
  assert_true(expect_ok(encode_remaining_length(16384)) == [128, 128, 1])
  let decoded = expect_ok(decode_remaining_length([128, 1], 0))
  assert_true(decoded.0 == 128)
  assert_true(decoded.1 == 2)
  assert_true(
    expect_err(decode_remaining_length([128, 128, 128, 128, 0], 0)).contains(
      "malformed",
    ),
  )
}

///|
test "mqtt string codec restores utf8 text and offset" {
  let encoded = expect_ok(encode_string("sensor/temp"))
  assert_true(
    encoded == [0, 11, 115, 101, 110, 115, 111, 114, 47, 116, 101, 109, 112],
  )
  let decoded = expect_ok(decode_string(encoded, 0))
  assert_true(decoded.0 == "sensor/temp")
  assert_true(decoded.1 == encoded.length())
  assert_true(expect_err(decode_string([0, 5, 97], 0)).contains("truncated"))
  assert_true(expect_err(decode_string([0, 1, 0], 0)).contains("U+0000"))
}

///|
test "mqtt binary codec preserves non utf8 bytes" {
  let encoded = expect_ok(encode_binary(b"\xff\x00\x01"))
  assert_true(encoded == [0x00, 0x03, 0xff, 0x00, 0x01])
  let decoded = expect_ok(decode_binary(encoded, 0))
  assert_true(decoded.0 == b"\xff\x00\x01")
  assert_true(decoded.1 == 5)
}

///|
test "connect encode matches MQTT 3.1.1 clean session packet" {
  let packet = expect_ok(
    encode_connect({
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
    }),
  )
  assert_true(
    packet ==
    [
      0x10, 0x10, 0x00, 0x04, 0x4d, 0x51, 0x54, 0x54, 0x04, 0x02, 0x00, 0x3c, 0x00,
      0x04, 0x6d, 0x6f, 0x6f, 0x6e,
    ],
  )
}

///|
test "connect decode restores optional user password and will fields" {
  let packet = expect_ok(
    encode_connect({
      client_id: "moon",
      username: Some("user"),
      password: Some(b"\xffsecret"),
      will_topic: Some("last/will"),
      will_message: Some(b"bye"),
      keep_alive: 30,
      flags: {
        username: true,
        password: true,
        will_retain: false,
        will_qos: QoS1,
        will_flag: true,
        clean_session: true,
      },
    }),
  )
  let connect = expect_ok(decode_connect(packet))
  assert_true(connect.client_id == "moon")
  assert_true(connect.username == Some("user"))
  assert_true(connect.password == Some(b"\xffsecret"))
  assert_true(connect.will_topic == Some("last/will"))
  assert_true(connect.will_message == Some(b"bye"))
  assert_true(connect.keep_alive == 30)
  assert_true(connect.flags.will_qos == QoS1)
  assert_true(connect.flags.clean_session)
  assert_true(
    expect_err(
      decode_connect([
        0x10, 0x0c, 0x00, 0x04, 0x4d, 0x51, 0x54, 0x54, 0x04, 0x01, 0x00, 0x00, 0x00,
        0x00,
      ]),
    ).contains("reserved"),
  )
}

///|
test "connack decode validates fixed header and return code" {
  assert_true(
    expect_ok(
      encode_connack({ session_present: false, return_code: ConnectionAccepted }),
    ) ==
    [0x20, 0x02, 0x00, 0x00],
  )
  let connack = expect_ok(decode_connack([0x20, 0x02, 0x00, 0x00]))
  assert_true(connack.session_present == false)
  assert_true(connack.return_code == ConnectionAccepted)
  assert_true(
    expect_err(decode_connack([0x20, 0x02, 0x00, 0x06])).contains("return code"),
  )
  assert_true(
    expect_err(decode_connack([0x22, 0x02, 0x00, 0x00])).contains("flags"),
  )
}

///|
test "publish qos0 encode and decode restores topic and payload" {
  let packet = expect_ok(
    encode_publish({
      topic: "test/topic",
      payload: b"hello",
      qos: QoS0,
      message_id: None,
      retain: false,
      dup: false,
    }),
  )
  assert_true(
    packet ==
    [
      0x30, 0x11, 0x00, 0x0a, 0x74, 0x65, 0x73, 0x74, 0x2f, 0x74, 0x6f, 0x70, 0x69,
      0x63, 0x68, 0x65, 0x6c, 0x6c, 0x6f,
    ],
  )
  let publish = expect_ok(decode_publish(packet))
  assert_true(publish.topic == "test/topic")
  assert_true(publish.payload == b"hello")
  assert_true(publish.qos == QoS0)
  assert_true(publish.message_id is None)
}

///|
test "publish qos1 decode restores packet id" {
  let publish = expect_ok(
    decode_publish([
      0x3a, 0x0c, 0x00, 0x03, 0x61, 0x2f, 0x62, 0x00, 0x07, 0x70, 0x61, 0x79, 0x6c,
      0x6f,
    ]),
  )
  assert_true(publish.topic == "a/b")
  assert_true(publish.qos == QoS1)
  assert_true(publish.message_id == Some(7))
  assert_true(publish.dup == true)
  assert_true(publish.payload == b"paylo")
  assert_true(
    expect_err(decode_publish([0x32, 0x04, 0x00, 0x01, 0x61, 0x00])).contains(
      "identifier",
    ),
  )
}

///|
test "publish qos2 encode and decode keeps packet id and payload" {
  let packet = expect_ok(
    encode_publish({
      topic: "qos/two",
      payload: b"data",
      qos: QoS2,
      message_id: Some(257),
      retain: true,
      dup: false,
    }),
  )
  assert_true(
    packet ==
    [
      0x35, 0x0f, 0x00, 0x07, 0x71, 0x6f, 0x73, 0x2f, 0x74, 0x77, 0x6f, 0x01, 0x01,
      0x64, 0x61, 0x74, 0x61,
    ],
  )
  let publish = expect_ok(decode_publish(packet))
  assert_true(publish.topic == "qos/two")
  assert_true(publish.qos == QoS2)
  assert_true(publish.message_id == Some(257))
  assert_true(publish.payload == b"data")
  assert_true(publish.retain)
  assert_true(
    expect_err(
      encode_publish({
        topic: "qos/+",
        payload: b"data",
        qos: QoS0,
        message_id: None,
        retain: false,
        dup: false,
      }),
    ).contains("wildcard"),
  )
}

///|
test "puback pubrec pubrel pubcomp helpers validate packet identifiers" {
  assert_true(expect_ok(encode_puback(7)) == [0x40, 0x02, 0x00, 0x07])
  assert_true(
    expect_ok(decode_puback([0x40, 0x02, 0x00, 0x07])).message_id == 7,
  )
  assert_true(expect_ok(encode_pubrec(8)) == [0x50, 0x02, 0x00, 0x08])
  assert_true(
    expect_ok(decode_pubrec([0x50, 0x02, 0x00, 0x08])).message_id == 8,
  )
  assert_true(expect_ok(encode_pubrel(9)) == [0x62, 0x02, 0x00, 0x09])
  assert_true(
    expect_ok(decode_pubrel([0x62, 0x02, 0x00, 0x09])).message_id == 9,
  )
  assert_true(expect_ok(encode_pubcomp(10)) == [0x70, 0x02, 0x00, 0x0a])
  assert_true(
    expect_ok(decode_pubcomp([0x70, 0x02, 0x00, 0x0a])).message_id == 10,
  )
  assert_true(
    expect_err(decode_pubrel([0x60, 0x02, 0x00, 0x09])).contains("flags"),
  )
  assert_true(
    expect_err(decode_puback([0x40, 0x02, 0x00, 0x00])).contains("identifier"),
  )
}

///|
test "subscribe and unsubscribe encode packets with MQTT required flags" {
  let subscribe = expect_ok(
    encode_subscribe({ topics: [{ topic: "a/b", qos: QoS1 }], message_id: 9 }),
  )
  assert_true(
    subscribe == [0x82, 0x08, 0x00, 0x09, 0x00, 0x03, 0x61, 0x2f, 0x62, 0x01],
  )
  let unsubscribe = expect_ok(
    encode_unsubscribe({ topics: ["a/b"], message_id: 10 }),
  )
  assert_true(
    unsubscribe == [0xa2, 0x07, 0x00, 0x0a, 0x00, 0x03, 0x61, 0x2f, 0x62],
  )
  let wildcard_subscribe = expect_ok(
    encode_subscribe({
      topics: [
        { topic: "sensors/+/temp", qos: QoS0 },
        { topic: "devices/#", qos: QoS1 },
      ],
      message_id: 11,
    }),
  )
  assert_true(wildcard_subscribe[0] == 0x82)
}

///|
test "subscribe and unsubscribe decode packet bodies" {
  let subscribe = expect_ok(
    decode_subscribe([
      0x82, 0x08, 0x00, 0x09, 0x00, 0x03, 0x61, 0x2f, 0x62, 0x01,
    ]),
  )
  assert_true(subscribe.message_id == 9)
  assert_true(subscribe.topics.length() == 1)
  assert_true(subscribe.topics[0].topic == "a/b")
  assert_true(subscribe.topics[0].qos == QoS1)
  let unsubscribe = expect_ok(
    decode_unsubscribe([0xa2, 0x07, 0x00, 0x0a, 0x00, 0x03, 0x61, 0x2f, 0x62]),
  )
  assert_true(unsubscribe.message_id == 10)
  assert_true(unsubscribe.topics == ["a/b"])
  assert_true(
    expect_err(
      decode_subscribe([
        0x80, 0x08, 0x00, 0x09, 0x00, 0x03, 0x61, 0x2f, 0x62, 0x01,
      ]),
    ).contains("flags"),
  )
  assert_true(
    expect_err(decode_subscribe([0x82, 0x05, 0x00, 0x09, 0x00, 0x00, 0x00])).contains(
      "empty",
    ),
  )
  assert_true(
    expect_err(
      encode_subscribe({
        topics: [{ topic: "sensor#", qos: QoS0 }],
        message_id: 12,
      }),
    ).contains("wildcard"),
  )
  assert_true(
    expect_err(
      decode_subscribe([
        0x82, 0x0a, 0x00, 0x0c, 0x00, 0x05, 0x61, 0x2f, 0x23, 0x2f, 0x62, 0x00,
      ]),
    ).contains("wildcard"),
  )
}

///|
test "suback and unsuback decode packet identifiers" {
  assert_true(
    expect_ok(
      encode_suback({ message_id: 9, return_codes: [SuccessQoS0, Failure] }),
    ) ==
    [0x90, 0x04, 0x00, 0x09, 0x00, 0x80],
  )
  let suback = expect_ok(decode_suback([0x90, 0x04, 0x00, 0x09, 0x00, 0x80]))
  assert_true(suback.message_id == 9)
  assert_true(suback.return_codes.length() == 2)
  assert_true(suback.return_codes[0] == SuccessQoS0)
  assert_true(suback.return_codes[1] == Failure)
  assert_true(expect_ok(encode_unsuback(10)) == [0xb0, 0x02, 0x00, 0x0a])
  let unsuback = expect_ok(decode_unsuback([0xb0, 0x02, 0x00, 0x0a]))
  assert_true(unsuback.message_id == 10)
}

///|
test "puback and empty control packet helpers" {
  assert_true(expect_ok(encode_pingreq()) == [0xc0, 0x00])
  assert_true(expect_ok(decode_pingreq([0xc0, 0x00])) == ())
  assert_true(expect_ok(encode_pingresp()) == [0xd0, 0x00])
  assert_true(expect_ok(decode_pingresp([0xd0, 0x00])) == ())
  assert_true(expect_ok(encode_disconnect()) == [0xe0, 0x00])
  assert_true(expect_ok(decode_disconnect([0xe0, 0x00])) == ())
  assert_true(is_pingresp([0xd0, 0x00]))
  assert_true(
    expect_err(decode_pingresp([0xd0, 0x00, 0x00])).contains("trailing"),
  )
}

///|
test "validation rejects malformed packet inputs" {
  assert_true(expect_err(encode_remaining_length(-1)).contains("range"))
  assert_true(expect_err(decode_remaining_length([], 0)).contains("missing"))
  assert_true(
    expect_err(decode_remaining_length([0x80], 0)).contains("truncated"),
  )
  assert_true(
    expect_err(decode_fixed_header([0x00, 0x00])).contains("message type"),
  )
  assert_true(expect_err(decode_fixed_header([0x36, 0x00])).contains("QoS"))
  assert_true(expect_err(decode_publish([0x20, 0x00])).contains("fixed header"))
  assert_true(
    expect_err(decode_publish([0x30, 0x05, 0x00, 0x03, 0x61, 0x2f, 0x2b])).contains(
      "wildcard",
    ),
  )
  assert_true(
    expect_err(decode_publish([0x32, 0x03, 0x00, 0x01, 0x61])).contains(
      "identifier",
    ),
  )
  assert_true(
    expect_err(
      encode_publish({
        topic: "a/b",
        payload: b"x",
        qos: QoS0,
        message_id: Some(1),
        retain: false,
        dup: false,
      }),
    ).contains("QoS0"),
  )
  assert_true(
    expect_err(
      encode_publish({
        topic: "",
        payload: b"x",
        qos: QoS0,
        message_id: None,
        retain: false,
        dup: false,
      }),
    ).contains("empty"),
  )
}

///|
test "validation rejects malformed connect and ack packets" {
  assert_true(
    expect_err(
      encode_connect({
        client_id: "moon",
        username: Some("user"),
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
      }),
    ).contains("username flag"),
  )
  assert_true(
    expect_err(
      decode_connect([
        0x10, 0x10, 0x00, 0x04, 0x4d, 0x51, 0x54, 0x73, 0x04, 0x02, 0x00, 0x3c, 0x00,
        0x04, 0x6d, 0x6f, 0x6f, 0x6e,
      ]),
    ).contains("protocol name"),
  )
  assert_true(
    expect_err(
      decode_connect([
        0x10, 0x10, 0x00, 0x04, 0x4d, 0x51, 0x54, 0x54, 0x05, 0x02, 0x00, 0x3c, 0x00,
        0x04, 0x6d, 0x6f, 0x6f, 0x6e,
      ]),
    ).contains("level"),
  )
  assert_true(
    expect_err(
      encode_connack({ session_present: true, return_code: ServerUnavailable }),
    ).contains("session_present"),
  )
  assert_true(
    expect_err(decode_connack([0x20, 0x02, 0x02, 0x00])).contains("acknowledge"),
  )
}

///|
test "validation rejects malformed subscribe and empty control packets" {
  assert_true(
    expect_err(encode_subscribe({ topics: [], message_id: 1 })).contains(
      "at least one",
    ),
  )
  assert_true(
    expect_err(
      encode_subscribe({ topics: [{ topic: "", qos: QoS0 }], message_id: 1 }),
    ).contains("empty"),
  )
  assert_true(
    expect_err(
      decode_subscribe([
        0x82, 0x08, 0x00, 0x09, 0x00, 0x03, 0x61, 0x2f, 0x62, 0x03,
      ]),
    ).contains("QoS"),
  )
  assert_true(
    expect_err(encode_suback({ message_id: 9, return_codes: [] })).contains(
      "return code",
    ),
  )
  assert_true(
    expect_err(decode_suback([0x90, 0x03, 0x00, 0x09, 0x03])).contains(
      "return code",
    ),
  )
  assert_true(
    expect_err(encode_unsubscribe({ topics: [], message_id: 10 })).contains(
      "at least one",
    ),
  )
  assert_true(expect_err(decode_disconnect([0xe0, 0x01, 0x00])).contains("0"))
  assert_true(expect_err(decode_disconnect([0xe2, 0x00])).contains("flags"))
}
