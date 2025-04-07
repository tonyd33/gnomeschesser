//// Gleam has removed yielders/iterators from their stdlib recently. We
//// implement a small inhouse version ourselves.
////
//// Like all proper iterators, evaluation is lazy. This flavor of
//// implementation uses a recursive approach, with a rough equivalent in
//// Haskell being:
//// ```haskell
//// data NextOrEnd a = Next a | End
//// data Iterator  a = Iterator a (a -> NextOrEnd a)
////
//// toList :: Iterator a -> [a]
//// toList (Iterator start fnext) = toList' start fnext []
////   where toList' x fnext acc = case fnext x of
////           Next x' -> toList' x' fnext (acc ++ [x'])
////           _       -> acc
//// ```

import gleam/list

pub type RecursiveIterator(a) {
  Iterator(start: a, next: fn(a) -> RecursiveNextOrEnd(a))
}

pub type RecursiveNextOrEnd(a) {
  Next(a)
  End
}

pub fn from_generator(start: a, next: fn(a) -> RecursiveNextOrEnd(a)) {
  Iterator(start, next)
}

pub fn fold(
  over iterator: RecursiveIterator(a),
  from initial: b,
  with fun: fn(b, a) -> b,
) {
  fold_inner(iterator, #(initial, iterator.start), fun)
}

fn fold_inner(
  over iterator: RecursiveIterator(a),
  acc acc: #(b, a),
  with fun: fn(b, a) -> b,
) -> b {
  let #(b, a) = acc
  case iterator.next(a) {
    Next(ap) -> fold_inner(iterator, #(fun(b, a), ap), fun)
    End -> b
  }
}

pub fn fold_until(
  over iterator: RecursiveIterator(a),
  from initial: b,
  with fun: fn(b, a) -> list.ContinueOrStop(b),
) {
  fold_until_inner(iterator, #(initial, iterator.start), fun)
}

fn fold_until_inner(
  over iterator: RecursiveIterator(a),
  acc acc: #(b, a),
  with fun: fn(b, a) -> list.ContinueOrStop(b),
) -> b {
  let #(b, a) = acc
  case iterator.next(a) {
    Next(ap) ->
      case fun(b, a) {
        list.Continue(bp) -> fold_until_inner(iterator, #(bp, ap), fun)
        list.Stop(bp) -> bp
      }
    End -> b
  }
}

pub fn to_list(iterator: RecursiveIterator(a)) -> List(a) {
  // Prepend should be O(1), as opposed to append being O(n)
  fold(iterator, [], fn(acc, x) { [x, ..acc] })
  // But we'll have to reverse it again
  |> list.reverse
}

fn to_list_inner(iterator: RecursiveIterator(a), x: a, xs: List(a)) -> List(a) {
  let xsp = list.append(xs, [x])
  case iterator.next(x) {
    Next(xp) -> to_list_inner(iterator, xp, xsp)
    End -> xsp
  }
}
