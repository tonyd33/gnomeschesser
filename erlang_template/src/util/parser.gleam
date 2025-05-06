//// Monadic parser combinators for Strings in gleam.
////
//// Very heavily inspired by Haskell's [Parsec library](https://hackage.haskell.org/package/parsec).
//// As such, please refer to Parsec's documentation when reading these
//// functions.
////
//// The only major differences between Parsec Parsers and our Parser are that:
//// - We backtrack automatically
//// - We only handle String inputs
////
//// A very brief summary of monadic parser combinators in Gleam:
//// - `Parser(a)` parses an `a` and returns the `a` as well as the rest of
////   the input stream. E.g. a `Parser(Bool)` might parse `"True foo"` as
////   `#(True, " foo")`.
//// - `Parser(a)` forms a monad under parser composition.
//// - Using Gleam's `use` notation gives us a reasonable substitute for
////   Haskell's `do` notation for monadic operations.
////
//// For further information on monadic parser combinators, refer to:
//// - [Article by Hasura](https://hasura.io/blog/parser-combinators-walkthrough)
//// - [Reading by Scott Wlaschin](https://fsharpforfunandprofit.com/posts/understanding-parser-combinators/)
////

import gleam/bool
import gleam/list
import gleam/result
import gleam/set
import gleam/string

type Lazy(a) =
  fn() -> a

pub type ParseError {
  ParseError(error: String, remaining: String)
}

type ParseResult(a) =
  Result(#(a, String), ParseError)

pub type Parser(a) =
  fn(String) -> ParseResult(a)

pub fn fmap(fa: Parser(a), f: fn(a) -> b) -> Parser(b) {
  fn(s) {
    fa(s)
    |> result.map(fn(a) { #(f(a.0), a.1) })
  }
}

pub const map = fmap

pub fn bind(fa: Parser(a), f: fn(a) -> Parser(b)) -> Parser(b) {
  fn(s) {
    fa(s)
    |> result.then(fn(a) { f(a.0)(a.1) })
  }
}

pub const then = bind

pub const chain = bind

pub const do = bind

pub fn ap(fab: Parser(fn(a) -> b), fa: Parser(a)) -> Parser(b) {
  fn(s) {
    use #(f, rest1) <- result.try(fab(s))
    use #(a, rest2) <- result.try(fa(rest1))
    Ok(#(f(a), rest2))
  }
}

pub fn alt(fa: Parser(a), that: Lazy(Parser(a))) -> Parser(a) {
  fn(s) {
    fa(s)
    |> result.or(that()(s))
  }
}

pub const or = alt

pub fn zero() -> Parser(a) {
  fn(s) { Error(ParseError("zero", s)) }
}

fn many_rec(pa: Parser(a), as_: List(a), s: String) {
  use <- bool.guard(string.is_empty(s), #(as_, s))

  case pa(s) {
    Error(_) -> #(as_, s)
    Ok(#(a, rest)) -> many_rec(pa, [a, ..as_], rest)
  }
}

pub fn many(pa: Parser(a)) -> Parser(List(a)) {
  fn(s) {
    let #(as_, i_) = many_rec(pa, [], s)
    Ok(#(list.reverse(as_), i_))
  }
}

pub fn many_1(pa: Parser(a)) -> Parser(List(a)) {
  fn(s) {
    use #(h, rest1) <- result.try(pa(s))
    use #(t, rest2) <- result.try(many(pa)(rest1))

    Ok(#([h, ..t], rest2))
  }
}

pub fn of(a: a) -> Parser(a) {
  fn(s) { Ok(#(a, s)) }
}

pub const pure = of

pub const return = of

pub fn choice(pas: List(Parser(a))) -> Parser(a) {
  list.fold_right(pas, zero(), fn(a, b) { alt(a, fn() { b }) })
}

pub fn sep_by_1(pa: Parser(a), sep: Parser(b)) -> Parser(List(a)) {
  use x <- bind(pa)
  use xs <- bind(many(bind(sep, fn(_) { pa })))

  return([x, ..xs])
}

pub fn sep_by(pa: Parser(a), sep: Parser(b)) -> Parser(List(a)) {
  alt(sep_by_1(pa, sep), fn() { return([]) })
}

pub fn option(a: a, pa: Parser(a)) -> Parser(a) {
  alt(pa, fn() { return(a) })
}

pub fn optional(pa: Parser(a)) -> Parser(Nil) {
  use _ <- bind(pa)
  return(Nil)
}

pub fn flat(pa: Parser(List(String))) -> Parser(String) {
  use xs <- fmap(pa)
  string.join(xs, "")
}

fn scan(pa: Parser(a), end: Parser(b)) {
  alt(
    {
      use _ <- bind(end)
      return([])
    },
    fn() {
      use x <- bind(pa)
      use xs <- bind(scan(pa, end))

      return([x, ..xs])
    },
  )
}

pub fn many_till(pa: Parser(a), end: Parser(b)) -> Parser(List(a)) {
  scan(pa, end)
}

pub fn lookahead(pa: Parser(a)) -> Parser(a) {
  fn(s) {
    pa(s)
    |> result.map(fn(x) { #(x.0, s) })
  }
}

pub fn satisfy(desc: String, pred: fn(String) -> Bool) -> Parser(String) {
  fn(i) {
    case string.pop_grapheme(i) {
      Error(_) -> Error(ParseError("Expected " <> desc <> ", but got EOF", i))
      Ok(#(h, rest)) ->
        case pred(h) {
          True -> Ok(#(h, rest))
          False ->
            Error(ParseError(
              "Expected " <> desc <> ", but got '" <> h <> "'",
              rest,
            ))
        }
    }
  }
}

pub fn one_of(of: String) -> Parser(String) {
  let s = set.from_list(string.to_graphemes(of))
  satisfy("one of \"" <> of <> "\"", fn(x) { set.contains(s, x) })
}

pub fn none_of(of: String) -> Parser(String) {
  let s = set.from_list(string.to_graphemes(of))
  satisfy("none of \"" <> of <> "\"", fn(x) { !set.contains(s, x) })
}

pub fn char(c: String) -> Parser(String) {
  satisfy("character \"" <> c <> "\"", fn(x) { x == c })
}

pub fn str(str: String) -> Parser(String) {
  fn(s) {
    case string.starts_with(s, str) {
      True -> Ok(#(str, string.drop_start(s, string.length(str))))
      False -> Error(ParseError("Expected \"" <> str <> "\"", s))
    }
  }
}

pub fn whitespace() -> Parser(String) {
  one_of("\n\t\r ")
}

pub fn whitespaces() -> Parser(String) {
  flat(many(whitespace()))
}

pub fn newline() -> Parser(String) {
  alt(char("\n"), fn() { str("\r\n") })
}

pub fn eof() -> Parser(String) {
  fn(s) {
    case string.is_empty(s) {
      True -> Ok(#("", s))
      False -> Error(ParseError("Expected EOF", s))
    }
  }
}

pub fn digit() {
  one_of("0123456789")
}

pub fn letter() {
  one_of("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
}

pub fn exec(pa: Parser(a), s: String) {
  pa(s)
}

pub fn run(pa: Parser(a), s: String) {
  result.map(pa(s), fn(x) { x.0 })
}
