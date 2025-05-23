//// UCI utilities.
//// See the [spec](https://github.com/tonyd33/node-uci-protocol/blob/master/engine-interface.txt)
////

import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
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
  InfoPrincipalVariation(moves: List(String))
  InfoMultiPrincipalVariation(n: Int)
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

pub type CopyProtectionStatus {
  CopyProtectionOk
  CopyProtectionError
}

pub type RegistrationStatus {
  RegistrationOk
  RegistrationChecking
  RegistrationError
}

pub type UCIGUICommand {
  GUICmdId(id: UCIId)
  GUICmdUCIOk
  GUICmdReadyOk
  GUICmdBestMove(move: String, ponder: Option(String))
  GUICmdCopyProtection(status: CopyProtectionStatus)
  GUICmdRegistration(status: RegistrationStatus)
  GUICmdInfo(params: List(UCIInfo))
  GUICmdOption(option: UCIOption)
}

fn on_off() -> Parser(Bool) {
  let on = p.map(p.str("on"), fn(_) { True })
  let off = p.map(p.str("off"), fn(_) { False })

  p.choice([on, off])
}

pub fn word() -> Parser(String) {
  p.many_1(p.none_of("\n\t\r "))
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

      p.return(PositionFEN(fen |> string.trim))
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

  use cmd <- p.do(
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
    ]),
  )

  use _ <- p.do(p.whitespaces())
  use _ <- p.do(p.eof())

  p.return(cmd)
}

fn tokenize_gui_cmd(cmd: UCIGUICommand) -> List(String) {
  let tokenize_id = fn(id: UCIId) {
    case id {
      Name(name) -> ["name", name]
      Author(author) -> ["author", author]
    }
  }
  let tokenize_copy_protection_status = fn(status: CopyProtectionStatus) {
    case status {
      CopyProtectionError -> "error"
      CopyProtectionOk -> "ok"
    }
  }
  let tokenize_registration_status = fn(status: RegistrationStatus) {
    case status {
      RegistrationChecking -> "checking"
      RegistrationError -> "error"
      RegistrationOk -> "ok"
    }
  }
  let tokenize_score = fn(score: UCIScore) {
    case score {
      ScoreCentipawns(n) -> ["cp", int.to_string(n)]
      ScoreLowerbound -> ["lowerbound"]
      ScoreMate(n) -> ["mate", int.to_string(n)]
      ScoreUpperbound -> ["upperbound"]
    }
  }
  let tokenize_info = fn(info: UCIInfo) {
    case info {
      InfoCPULoad(n) -> ["cpuload", int.to_string(n)]
      InfoCurrLine(cpunr, moves) -> ["currline", int.to_string(cpunr), ..moves]
      InfoCurrMove(move) -> ["currmove", move]
      InfoCurrMoveNumber(n) -> ["currmovenumber", int.to_string(n)]
      InfoDepth(n) -> ["depth", int.to_string(n)]
      InfoHashFull(n) -> ["hashfull", int.to_string(n)]
      InfoMultiPrincipalVariation(n) -> ["multipv", int.to_string(n)]
      InfoNodes(n) -> ["nodes", int.to_string(n)]
      InfoNodesPerSecond(n) -> ["nps", int.to_string(n)]
      InfoPrincipalVariation(moves) -> ["pv", ..moves]
      InfoRefutation(moves) -> ["refutation", ..moves]
      InfoScore(params) -> ["score", ..list.flat_map(params, tokenize_score)]
      InfoSelDepth(n) -> ["seldepth", int.to_string(n)]
      InfoShredderBaseHits(n) -> ["sbhits", int.to_string(n)]
      InfoString(s) -> ["string", s]
      InfoTableBaseHits(n) -> ["tbhits", int.to_string(n)]
      InfoTime(n) -> ["time", int.to_string(n)]
    }
  }
  let tokenize_option_type = fn(option_type: UCIOptionType) {
    case option_type {
      OptionTypeButton -> ["button"]
      OptionTypeCheck -> ["spin"]
      OptionTypeCombo -> ["combo"]
      OptionTypeString -> ["string"]
    }
  }
  let tokenize_option = fn(option: UCIOption) {
    list.flatten([
      ["name", option.name, "type"],
      tokenize_option_type(option.type_),
      option.default
        |> option.map(fn(d) { ["default", d] })
        |> option.unwrap([]),
      option.min
        |> option.map(fn(d) { ["min", d] })
        |> option.unwrap([]),
      option.max
        |> option.map(fn(d) { ["max", d] })
        |> option.unwrap([]),
      option.var
        |> option.map(fn(d) { ["var", d] })
        |> option.unwrap([]),
    ])
  }
  case cmd {
    GUICmdId(id) -> ["id", ..tokenize_id(id)]
    GUICmdUCIOk -> ["uciok"]
    GUICmdReadyOk -> ["readyok"]
    GUICmdBestMove(move, ponder) -> [
      "bestmove",
      move,
      ..{ ponder |> option.map(fn(d) { [d] }) |> option.unwrap([]) }
    ]
    GUICmdCopyProtection(status) -> [
      "copyprotection",
      tokenize_copy_protection_status(status),
    ]
    GUICmdRegistration(status) -> [
      "registration",
      tokenize_registration_status(status),
    ]
    GUICmdInfo(params) -> ["info", ..list.flat_map(params, tokenize_info)]
    GUICmdOption(option) -> ["option", ..tokenize_option(option)]
  }
}

pub fn serialize_gui_cmd(cmd: UCIGUICommand) -> String {
  tokenize_gui_cmd(cmd)
  |> string.join(" ")
}
