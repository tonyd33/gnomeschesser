import gleam/float
import gleam/int
import gleam/option.{type Option, None, Some}
import util/parser.{type Parser} as p

pub type UCIRegister {
  RegisterLater
  RegisterName(name: String)
  RegisterCode(code: String)
}

pub type UCIPosition {
  PositionFEN(fen: String)
  PositionStartPos
}

pub type UCIScore {
  ScoreCentipawns(n: Int)
  ScoreMate(n: Int)
  ScoreLowerbound
  ScoreUpperbound
}

pub type UCIInfo {
  InfoDepth(depth: Int)
  InfoSelDepth(depth: Int)
  InfoTime(time: Int)
  InfoNodes(nodes: Int)
  InfoPreview(moves: List(String))
  InfoMultiPreview(n: Int)
  InfoScore(params: List(UCIScore))
  InfoCurrMove(move: String)
  InfoCurrMoveNumber(n: Int)
  InfoHashFull(n: Int)
  InfoNodesPerSecond(n: Int)
  InfoTableBaseHits(n: Int)
  InfoShredderBaseHits(n: Int)
  InfoCPULoad(n: Int)
  InfoString(s: String)
  InfoRefutation(moves: List(String))
  InfoCurrLine(cpunr: Int, moves: List(String))
}

pub type UCIGoParameter {
  GoParamSearchMoves(moves: List(String))
  GoParamPonder
  GoParamWTime(time: Int)
  GoParamBTime(time: Int)
  GoParamWInc(time: Int)
  GoParamBInc(time: Int)
  GoParamMovesToGo(n: Int)
  GoParamDepth(depth: Int)
  GoParamNodes(nodes: Int)
  GoParamMate(n: Int)
  GoParamMoveTime(time: Int)
  GoParamInfinite
}

pub type UCIEngineCommand {
  EngCmdUCI
  EngCmdDebug(on: Option(Bool))
  EngCmdIsReady
  EngCmdSetOption(name: String, value: Option(String))
  EngCmdRegister(register: UCIRegister)
  EngCmdUCINewGame
  EngCmdPosition(position: UCIPosition, moves: List(String))
  EngCmdGo(params: List(UCIGoParameter))
  EngCmdStop
  EngCmdPonderhit
  EngCmdQuit
}

pub type UCIId {
  Name(name: String)
  Author(author: String)
}

pub type UCIOptionType {
  OptionTypeCheck
  OptionTypeCombo
  OptionTypeButton
  OptionTypeString
}

pub type UCIOption {
  UCIOption(
    name: String,
    type_: UCIOptionType,
    default: Option(String),
    min: Option(String),
    max: Option(String),
    var: Option(String),
  )
}

fn on_off() -> Parser(Bool) {
  let on = p.map(p.str("on"), fn(_) { True })
  let off = p.map(p.str("off"), fn(_) { False })

  p.choice([on, off])
}

pub fn word() -> Parser(String) {
  p.none_of(" ")
  |> p.many_till(p.lookahead(p.choice([p.whitespace(), p.eof()])))
  |> p.flat
}

pub fn words() -> Parser(List(String)) {
  p.sep_by(word(), p.whitespaces())
}

fn natural() -> Parser(Int) {
  p.many_1(p.digit())
  |> p.flat
  |> p.map(fn(sx) {
    // should never fail
    let assert Ok(ix) = int.parse(sx)
    ix
  })
}

fn p_int() -> Parser(Int) {
  use sign <- p.do(p.option("+", p.one_of("-+")))
  use nat <- p.do(natural())

  case sign {
    "+" -> p.return(nat)
    "-" -> p.return(-nat)
    _ -> panic as "There is a bug in the code"
  }
}

fn floating() -> Parser(Float) {
  use left <- p.do(p_int())
  use dot <- p.do(p.char("."))
  use right <- p.do(natural())

  // loooooooool
  let assert Ok(fl) =
    float.parse(int.to_string(left) <> dot <> int.to_string(right))

  p.return(fl)
}

pub fn engine_cmd() -> Parser(UCIEngineCommand) {
  let uci = p.map(p.str("uci"), fn(_) { EngCmdUCI })
  let debug = {
    use _ <- p.do(p.str("debug"))
    use _ <- p.do(p.whitespaces())
    use on <- p.do(p.option(None, p.map(on_off(), Some)))
    p.return(EngCmdDebug(on))
  }
  let is_ready = p.map(p.str("isready"), fn(_) { EngCmdIsReady })
  let set_option = {
    let p_set_option_id = {
      use _ <- p.do(p.str("name"))
      use _ <- p.do(p.whitespaces())
      p.none_of("\n")
      |> p.many_till(
        p.lookahead(
          p.choice([
            p.whitespaces() |> p.chain(fn(_) { p.str("value") }),
            p.newline(),
            p.eof(),
          ]),
        ),
      )
      |> p.flat
    }
    let p_set_option_value = {
      use _ <- p.do(p.str("value"))
      use _ <- p.do(p.whitespaces())
      p.none_of("\n")
      |> p.many_till(p.choice([p.newline(), p.eof()]))
      |> p.flat
    }
    use _ <- p.do(p.str("setoption"))
    use _ <- p.do(p.whitespaces())
    use name <- p.do(p_set_option_id)
    use _ <- p.do(p.whitespaces())
    use value <- p.do(p.option(None, p.map(p_set_option_value, Some)))

    p.return(EngCmdSetOption(name, value))
  }
  let new_game = p.map(p.str("ucinewgame"), fn(_) { EngCmdUCINewGame })
  let position = {
    let p_fen = {
      use _ <- p.do(p.str("fen"))
      use _ <- p.do(p.whitespaces())
      use fen <- p.do(
        p.none_of("\n")
        |> p.many_till(
          p.lookahead(p.choice([p.str("moves"), p.newline(), p.eof()])),
        )
        |> p.flat,
      )

      p.return(PositionFEN(fen))
    }
    let p_startpos = p.map(p.str("startpos"), fn(_) { PositionStartPos })
    let moves = {
      use _ <- p.do(p.str("moves"))
      use _ <- p.do(p.whitespaces())
      words()
    }

    use _ <- p.do(p.str("position"))
    use _ <- p.do(p.whitespaces())
    use position <- p.do(p.choice([p_fen, p_startpos]))
    use _ <- p.do(p.whitespaces())
    use moves <- p.do(p.option([], moves))

    p.return(EngCmdPosition(position, moves))
  }
  let go = {
    let search_moves = {
      use _ <- p.do(p.str("searchmoves"))
      use _ <- p.do(p.whitespaces())
      use moves <- p.do(words())
      p.return(GoParamSearchMoves(moves))
    }
    let ponder = p.map(p.str("ponder"), fn(_) { GoParamPonder })
    let wtime = {
      use _ <- p.do(p.str("wtime"))
      use _ <- p.do(p.whitespaces())
      use time <- p.do(p_int())
      p.return(GoParamWTime(time))
    }
    let btime = {
      use _ <- p.do(p.str("btime"))
      use _ <- p.do(p.whitespaces())
      use time <- p.do(p_int())
      p.return(GoParamBTime(time))
    }
    let winc = {
      use _ <- p.do(p.str("winc"))
      use _ <- p.do(p.whitespaces())
      use time <- p.do(p_int())
      p.return(GoParamWInc(time))
    }
    let binc = {
      use _ <- p.do(p.str("binc"))
      use _ <- p.do(p.whitespaces())
      use time <- p.do(p_int())
      p.return(GoParamBInc(time))
    }
    let moves_to_go = {
      use _ <- p.do(p.str("movestogo"))
      use _ <- p.do(p.whitespaces())
      use n <- p.do(p_int())
      p.return(GoParamMovesToGo(n))
    }
    let depth = {
      use _ <- p.do(p.str("depth"))
      use _ <- p.do(p.whitespaces())
      use depth <- p.do(p_int())
      p.return(GoParamDepth(depth))
    }
    let nodes = {
      use _ <- p.do(p.str("nodes"))
      use _ <- p.do(p.whitespaces())
      use nodes <- p.do(p_int())
      p.return(GoParamNodes(nodes))
    }
    let mate = {
      use _ <- p.do(p.str("mate"))
      use _ <- p.do(p.whitespaces())
      use n <- p.do(p_int())
      p.return(GoParamMate(n))
    }
    let movetime = {
      use _ <- p.do(p.str("movetime"))
      use _ <- p.do(p.whitespaces())
      use n <- p.do(p_int())
      p.return(GoParamMoveTime(n))
    }
    let infinite = p.map(p.str("infinite"), fn(_) { GoParamInfinite })
    let p_params =
      p.choice([
        search_moves,
        ponder,
        wtime,
        btime,
        winc,
        binc,
        moves_to_go,
        depth,
        nodes,
        mate,
        movetime,
        infinite,
      ])

    use _ <- p.do(p.str("go"))
    use _ <- p.do(p.whitespaces())
    use params <- p.do(p.sep_by(p_params, p.whitespaces()))
    p.return(EngCmdGo(params))
  }
  let stop = p.map(p.str("stop"), fn(_) { EngCmdStop })
  let ponderhit = p.map(p.str("ponderhit"), fn(_) { EngCmdPonderhit })
  let quit = p.map(p.str("quit"), fn(_) { EngCmdQuit })

  p.choice([
    uci,
    debug,
    is_ready,
    set_option,
    new_game,
    position,
    go,
    stop,
    ponderhit,
    quit,
  ])
}
