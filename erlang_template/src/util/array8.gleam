import gleam/list.{Continue, Stop}

pub type Array8(a) {
  Array8(x0: a, x1: a, x2: a, x3: a, x4: a, x5: a, x6: a, x7: a)
}

pub fn of(a) {
  Array8(x0: a, x1: a, x2: a, x3: a, x4: a, x5: a, x6: a, x7: a)
}

pub fn set(array8: Array8(a), idx: Int, a: a) {
  case idx {
    0 -> Ok(Array8(..array8, x0: a))
    1 -> Ok(Array8(..array8, x1: a))
    2 -> Ok(Array8(..array8, x2: a))
    3 -> Ok(Array8(..array8, x3: a))
    4 -> Ok(Array8(..array8, x4: a))
    5 -> Ok(Array8(..array8, x5: a))
    6 -> Ok(Array8(..array8, x6: a))
    7 -> Ok(Array8(..array8, x7: a))
    _ -> Error(Nil)
  }
}

pub fn update(array8: Array8(a), idx: Int, f: fn(a) -> a) {
  case idx {
    0 -> Ok(Array8(..array8, x0: f(array8.x0)))
    1 -> Ok(Array8(..array8, x1: f(array8.x1)))
    2 -> Ok(Array8(..array8, x2: f(array8.x2)))
    3 -> Ok(Array8(..array8, x3: f(array8.x3)))
    4 -> Ok(Array8(..array8, x4: f(array8.x4)))
    5 -> Ok(Array8(..array8, x5: f(array8.x5)))
    6 -> Ok(Array8(..array8, x6: f(array8.x6)))
    7 -> Ok(Array8(..array8, x7: f(array8.x7)))
    _ -> Error(Nil)
  }
}

pub fn get(array8: Array8(a), idx: Int) {
  case idx {
    0 -> Ok(array8.x0)
    1 -> Ok(array8.x1)
    2 -> Ok(array8.x2)
    3 -> Ok(array8.x3)
    4 -> Ok(array8.x4)
    5 -> Ok(array8.x5)
    6 -> Ok(array8.x6)
    7 -> Ok(array8.x7)
    _ -> Error(Nil)
  }
}

pub fn fold(
  over array: Array8(a),
  from initial: acc,
  with fun: fn(acc, a) -> acc,
) -> acc {
  fun(initial, array.x0)
  |> fun(array.x1)
  |> fun(array.x2)
  |> fun(array.x3)
  |> fun(array.x4)
  |> fun(array.x5)
  |> fun(array.x6)
  |> fun(array.x7)
}

pub fn fold_until(
  over array: Array8(a),
  from acc: acc,
  with fun: fn(acc, a) -> list.ContinueOrStop(acc),
) -> acc {
  // This is art.
  case fun(acc, array.x0) {
    Continue(acc) ->
      case fun(acc, array.x1) {
        Continue(acc) ->
          case fun(acc, array.x2) {
            Continue(acc) ->
              case fun(acc, array.x3) {
                Continue(acc) ->
                  case fun(acc, array.x4) {
                    Continue(acc) ->
                      case fun(acc, array.x5) {
                        Continue(acc) ->
                          case fun(acc, array.x6) {
                            Continue(acc) ->
                              case fun(acc, array.x7) {
                                Continue(acc) -> acc
                                Stop(acc) -> acc
                              }
                            Stop(acc) -> acc
                          }
                        Stop(acc) -> acc
                      }
                    Stop(acc) -> acc
                  }
                Stop(acc) -> acc
              }
            Stop(acc) -> acc
          }
        Stop(acc) -> acc
      }
    Stop(acc) -> acc
  }
}

pub fn find(in array: Array8(a), one_that fun: fn(a) -> Bool) {
  case fun(array.x0) {
    False ->
      case fun(array.x1) {
        False ->
          case fun(array.x2) {
            False ->
              case fun(array.x3) {
                False ->
                  case fun(array.x4) {
                    False ->
                      case fun(array.x5) {
                        False ->
                          case fun(array.x6) {
                            False ->
                              case fun(array.x7) {
                                False -> Error(Nil)
                                True -> Ok(array.x7)
                              }
                            True -> Ok(array.x6)
                          }
                        True -> Ok(array.x5)
                      }
                    True -> Ok(array.x4)
                  }
                True -> Ok(array.x3)
              }
            True -> Ok(array.x2)
          }
        True -> Ok(array.x1)
      }
    True -> Ok(array.x0)
  }
}

pub fn find_index(in array: Array8(a), one_that fun: fn(a) -> Bool) {
  case fun(array.x0) {
    False ->
      case fun(array.x1) {
        False ->
          case fun(array.x2) {
            False ->
              case fun(array.x3) {
                False ->
                  case fun(array.x4) {
                    False ->
                      case fun(array.x5) {
                        False ->
                          case fun(array.x6) {
                            False ->
                              case fun(array.x7) {
                                False -> Error(Nil)
                                True -> Ok(7)
                              }
                            True -> Ok(6)
                          }
                        True -> Ok(5)
                      }
                    True -> Ok(4)
                  }
                True -> Ok(3)
              }
            True -> Ok(2)
          }
        True -> Ok(1)
      }
    True -> Ok(0)
  }
}
