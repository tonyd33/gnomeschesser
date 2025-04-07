import gleam/list
import gleeunit/should
import util/recursive_iterator

pub fn recursive_iterator_fold_range_test() {
  let it =
    recursive_iterator.from_generator(1, fn(x) {
      case x < 5 {
        True -> recursive_iterator.Next(x + 1)
        False -> recursive_iterator.End
      }
    })
  recursive_iterator.fold(it, [], fn(acc, val) { list.append(acc, [val]) })
  |> should.equal([1, 2, 3, 4])
}

pub fn recursive_iterator_fold_until_test() {
  let it =
    recursive_iterator.from_generator(1, fn(x) {
      case x < 10 {
        True -> recursive_iterator.Next(x + 1)
        False -> recursive_iterator.End
      }
    })

  recursive_iterator.fold_until(it, [], fn(acc, val) {
    case list.length(acc) < 5 {
      True -> list.Continue(list.append(acc, [val]))
      False -> list.Stop(acc)
    }
  })
  |> should.equal([1, 2, 3, 4, 5])
}
