import gleam/erlang/process
import uci_server

pub fn main() {
  uci_server.start_robot()
  process.sleep_forever()
}
