import gleam/erlang/process
import web_server

pub fn main() {
  web_server.start_robot()
  process.sleep_forever()
}
