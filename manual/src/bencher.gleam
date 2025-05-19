import gleam/dict

@external(erlang, "Elixir.Benchee", "run")
pub fn run(
  functions: dict.Dict(String, fn(input_type) -> output_type),
  configuration: List(BencheeConfiguration(input_type)),
) -> Nil

pub type BencheeConfiguration(input_type) {
  MemoryTime(seconds: Int)
  Parallel(processes: Int)
  ReductionTime(seconds: Int)
  Time(seconds: Int)
  Warmup(seconds: Int)
  Inputs(inputs: dict.Dict(String, input_type))
}
