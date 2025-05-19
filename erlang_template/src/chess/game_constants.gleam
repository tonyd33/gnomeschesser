import iv

pub type GameConstants {
  GameConstants(piece_attack_offsets: PieceAttackOffsets)
}

pub type PieceAttackOffsets {
  PieceAttackOffsets(
    knight: iv.Array(Int),
    bishop: iv.Array(Int),
    king: iv.Array(Int),
    white_pawn: iv.Array(Int),
    black_pawn: iv.Array(Int),
    queen: iv.Array(Int),
    rook: iv.Array(Int),
  )
}

pub fn new() {
  GameConstants(piece_attack_offsets: new_piece_attack_offsets())
}

fn new_piece_attack_offsets() {
  PieceAttackOffsets(
    knight: iv.from_list([-18, -33, -31, -14, 18, 33, 31, 14]),
    bishop: iv.from_list([-17, -15, 17, 15]),
    king: iv.from_list([-17, -16, -15, 1, 17, 16, 15, -1]),
    white_pawn: iv.from_list([17, 15]),
    black_pawn: iv.from_list([-17, -15]),
    queen: iv.from_list([-17, -16, -15, 1, 17, 16, 15, -1]),
    rook: iv.from_list([-16, 1, 16, -1]),
  )
}
