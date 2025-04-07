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
/// |> expect_or(
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
/// |> expect_or(fn(x) { {x % 2} == 0 }, fn(_) { Nil })
/// // -> Error(Nil)
/// ```
///
pub fn expect_or(
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

pub fn expect_unsafe_panic(res: Result(a, b)) -> a {
  let assert Ok(val) = res
  val
}

/// Similar guard to bool.guard and should be used similarly in situations
/// where we'd like to short-circuit execution of a function *not returning a
/// result* based on whether a result was successful. If the function returns a
/// result, `result.try` should be used. Note that this ends up discarding the
/// error.
///
/// Examples:
/// ```gleam
/// fn get_a_list() -> List(a) {
///   use needed_value <- guard(dangerous(), [])
///   // ...
///   // a lot of code
///   // ...
/// }
/// ```
///
pub fn guard(result: Result(a, e), or default: b, apply fun: fn(a) -> b) {
  case result {
    Ok(x) -> fun(x)
    Error(_) -> default
  }
}
