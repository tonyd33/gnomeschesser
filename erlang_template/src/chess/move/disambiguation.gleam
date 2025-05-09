import gleam/bool

/// How ambiguous a move is. Used when converting to SAN.
/// https://en.wikipedia.org/wiki/Algebraic_notation_(chess)#Disambiguating_moves
///
pub type DisambiguationLevel {
  // There is only one move to a position with a fixed piece
  Unambiguous
  // There is a move with the same piece of a different rank and life moving
  // to the same square.
  // GenerallyAmbiguous will end up disambiguating to include the file like
  // Rank does, we need this extra enum member for the
  // `add` algebra to work out correctly
  GenerallyAmbiguous
  // There is a move with the piece on the same rank moving to the same
  // square
  Rank
  // There is a move with the same piece on the same file moving to the same
  // square
  File
  // There is a move with the same piece on the same file and another move with
  // the same piece on the same rank moving to the same square
  Both
}

pub fn add(l1: DisambiguationLevel, l2: DisambiguationLevel) {
  use <- bool.guard(l1 == l2, l1)

  case l1, l2 {
    Both, _ -> Both
    _, Both -> Both

    Unambiguous, other -> other

    GenerallyAmbiguous, File -> File
    GenerallyAmbiguous, Rank -> Rank

    Rank, File -> Both

    _, _ -> add(l2, l1)
  }
}
