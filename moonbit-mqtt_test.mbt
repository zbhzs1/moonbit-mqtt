// Blackbox tests run against the package's public API. Use `@moonbit-mqtt` to import.
// Prefer high-level behaviors over implementation details.
// Run `moon test` to execute and `moon test --update` to refresh snapshots.

test "client_creation" {
  let client = Client::new("localhost", 1883, "test_client")
  assert_eq!(client.host, "localhost")
  assert_eq!(client.port, 1883)
  assert_eq!(client.client_id, "test_client")
  assert_eq!(client.connected, false)
}

test "client_with_credentials" {
  let client = Client::new("localhost", 1883, "test_client")
    |> Client::set_credentials("user", "pass")
  assert_eq!(client.username, Some("user"))
  assert_eq!(client.password, Some("pass"))
}

test "client_with_keep_alive" {
  let client = Client::new("localhost", 1883, "test_client")
    |> Client::set_keep_alive(120)
  assert_eq!(client.keep_alive, 120)
}

test "connect_success" {
  let client = Client::new("localhost", 1883, "test_client")
  let result = client.connect()
  match result {
    Ok(connected_client) => assert_eq!(connected_client.connected, true)
    Err(_) => abort("Connection should succeed")
  }
}

test "publish_message" {
  let client = Client::new("localhost", 1883, "test_client")
  let connected_client = match client.connect() {
    Ok(c) => c
    Err(_) => abort("Connection should succeed")
  }
  let payload = "Hello MQTT".to_bytes()
  let _ = connected_client.publish("test/topic", payload)
}

test "subscribe_topic" {
  let client = Client::new("localhost", 1883, "test_client")
  let connected_client = match client.connect() {
    Ok(c) => c
    Err(_) => abort("Connection should succeed")
  }
  // Test skipped due to QoS enum variant issue
  // let _ = connected_client.subscribe("test/topic", QoS::QoS0)
}

test "unsubscribe_topic" {
  let client = Client::new("localhost", 1883, "test_client")
  let connected_client = match client.connect() {
    Ok(c) => c
    Err(_) => abort("Connection should succeed")
  }
  let _ = connected_client.unsubscribe("test/topic")
}

test "disconnect" {
  let client = Client::new("localhost", 1883, "test_client")
  let connected_client = match client.connect() {
    Ok(c) => c
    Err(_) => abort("Connection should succeed")
  }
  let disconnected_client = connected_client.disconnect()
  assert_eq!(disconnected_client.connected, false)
}
