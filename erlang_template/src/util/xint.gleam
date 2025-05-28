//// Extended integers
////

import gleam/int
import gleam/order

pub type ExtendedInt {
  NegInf
  Finite(Int)
  PosInf
}

pub fn absolute_value(ea) {
  case ea {
    NegInf -> PosInf
    Finite(a) -> Finite(int.absolute_value(a))
    PosInf -> PosInf
  }
}

pub fn add(ea, eb) {
  case ea, eb {
    PosInf, NegInf -> panic as "Indeterminate: ∞ + (−∞)"
    NegInf, PosInf -> panic as "Indeterminate: −∞ + ∞"

    PosInf, _ -> PosInf
    _, PosInf -> PosInf

    NegInf, _ -> NegInf
    _, NegInf -> NegInf

    Finite(a), Finite(b) -> Finite(a + b)
  }
}

pub fn safe_add(ea, eb) {
  case ea, eb {
    PosInf, NegInf -> Error(Nil)
    NegInf, PosInf -> Error(Nil)

    PosInf, _ -> Ok(PosInf)
    _, PosInf -> Ok(PosInf)

    NegInf, _ -> Ok(NegInf)
    _, NegInf -> Ok(NegInf)

    Finite(a), Finite(b) -> Ok(Finite(a + b))
  }
}

pub fn subtract(ea, eb) {
  add(ea, negate(eb))
}

pub fn multiply(ea, eb) {
  case ea, eb {
    PosInf, Finite(b) if b > 0 -> PosInf
    PosInf, Finite(b) if b < 0 -> NegInf
    // if b == 0
    PosInf, Finite(_) -> panic as "Indeterminate: ∞ * 0"
    Finite(b), PosInf -> multiply(PosInf, Finite(b))

    NegInf, Finite(b) if b > 0 -> NegInf
    NegInf, Finite(b) if b < 0 -> PosInf
    // if b == 0
    NegInf, Finite(_) -> panic as "Indeterminate: -∞ * 0"
    Finite(b), NegInf -> multiply(NegInf, Finite(b))

    PosInf, PosInf -> PosInf
    NegInf, NegInf -> PosInf
    PosInf, NegInf -> NegInf
    NegInf, PosInf -> NegInf

    Finite(a), Finite(b) -> Finite(a * b)
  }
}

pub fn safe_multiply(ea, eb) {
  case ea, eb {
    PosInf, Finite(b) if b > 0 -> Ok(PosInf)
    PosInf, Finite(b) if b < 0 -> Ok(NegInf)
    // if b == 0
    PosInf, Finite(_) -> Error(Nil)
    Finite(b), PosInf -> Ok(multiply(PosInf, Finite(b)))

    NegInf, Finite(b) if b > 0 -> Ok(NegInf)
    NegInf, Finite(b) if b < 0 -> Ok(PosInf)
    // if b == 0
    NegInf, Finite(_) -> Error(Nil)
    Finite(b), NegInf -> Ok(multiply(NegInf, Finite(b)))

    PosInf, PosInf -> Ok(PosInf)
    NegInf, NegInf -> Ok(PosInf)
    PosInf, NegInf -> Ok(NegInf)
    NegInf, PosInf -> Ok(NegInf)

    Finite(a), Finite(b) -> Ok(Finite(a * b))
  }
}

pub fn sign(ea) {
  case ea {
    NegInf -> -1
    Finite(x) if x > 0 -> 1
    Finite(x) if x < 0 -> -1
    // if x == 0
    Finite(_) -> 0
    PosInf -> 1
  }
}

pub fn negate(ea) {
  case ea {
    NegInf -> PosInf
    Finite(x) -> Finite(-x)
    PosInf -> NegInf
  }
}

pub fn from_int(a) {
  Finite(a)
}

pub fn to_int(ea) {
  case ea {
    Finite(a) -> Ok(a)
    _ -> Error(Nil)
  }
}

pub fn to_string(ea) {
  case ea {
    NegInf -> "-Infinity"
    Finite(a) -> int.to_string(a)
    PosInf -> "Infinity"
  }
}

pub fn compare(ea, eb) {
  case ea, eb {
    Finite(a), Finite(b) -> int.compare(a, b)
    NegInf, NegInf -> order.Eq
    NegInf, _ -> order.Lt
    _, NegInf -> order.Gt
    PosInf, PosInf -> order.Eq
    PosInf, _ -> order.Gt
    _, PosInf -> order.Lt
  }
}

pub fn gte(ea, eb) {
  case compare(ea, eb) {
    order.Gt -> True
    order.Eq -> True
    _ -> False
  }
}

pub fn gt(ea, eb) {
  case compare(ea, eb) {
    order.Gt -> True
    _ -> False
  }
}

pub fn lte(ea, eb) {
  case compare(ea, eb) {
    order.Lt -> True
    order.Eq -> True
    _ -> False
  }
}

pub fn lt(ea, eb) {
  case compare(ea, eb) {
    order.Lt -> True
    _ -> False
  }
}

pub fn min(ea, eb) {
  case compare(ea, eb) {
    order.Lt -> ea
    _ -> eb
  }
}

pub fn max(ea, eb) {
  case compare(ea, eb) {
    order.Gt -> ea
    _ -> eb
  }
}
