import gleam/result

/// Assert that a result satisfies `pred`. Useful when we need to guard a
/// condition within a result. This function helps clarify the semantics of an
/// assertion, which may otherwise be hard to recognize, especially for complex
/// predicates. For example, the code below is trying to assert that a number
/// result is prime.
/// ```gleam
/// let prime_number_result = int.floor_divide(7, 2)
/// |> result.try(fn(x) {
///   let is_prime = list.range(2, x)
///   |> list.all(fn(p) { {x % p} != 0 })
///   case is_prime {
///     True -> Ok(x)
///     False -> Error(Nil)
///   }
/// })
/// ```
///
/// Examples:
/// ```gleam
/// let prime_number_result = int.floor_divide(7, 2)
/// |> assert_result(
///    fn(x) {
///      is_prime = list.range(2, x)
///      |> list.all(fn(p) { {x % p} != 0 })
///    },
///    fn(_) { Nil }
///   )
/// // -> Ok(3)
/// ```
///
/// ```gleam
/// let even_number_result = int.floor_divide(7, 2)
/// |> assert_result(fn(x) { {x % 2} == 0 }, fn(_) { Nil })
/// // -> Error(Nil)
/// ```
///
pub fn assert_result(
  res: Result(a, b),
  pred: fn(a) -> Bool,
  otherwise: fn(a) -> b,
) -> Result(a, b) {
  result.try(res, fn(val) {
    case pred(val) {
      True -> Ok(val)
      False -> Error(otherwise(val))
    }
  })
}

pub fn result_expect(res: Result(a, b)) -> a {
  let assert Ok(val) = res
  val
}
