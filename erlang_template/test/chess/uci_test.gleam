import chess/uci
import gleam/option.{None, Some}
import gleeunit/should
import util/parser as p

pub fn uci_engine_cmd_test() {
  uci.engine_cmd()
  |> p.run("uci")
  |> should.equal(Ok(uci.EngCmdUCI))

  uci.engine_cmd()
  |> p.run("debug on")
  |> should.equal(Ok(uci.EngCmdDebug(Some(True))))

  uci.engine_cmd()
  |> p.run("debug off")
  |> should.equal(Ok(uci.EngCmdDebug(Some(False))))

  uci.engine_cmd()
  |> p.run("debug")
  |> should.equal(Ok(uci.EngCmdDebug(None)))

  uci.engine_cmd()
  |> p.run("isready")
  |> should.equal(Ok(uci.EngCmdIsReady))

  uci.engine_cmd()
  |> p.run("setoption name Nullmove value true")
  |> should.equal(Ok(uci.EngCmdSetOption("Nullmove", Some("true"))))

  uci.engine_cmd()
  |> p.run("setoption name Selectivity value 3")
  |> should.equal(Ok(uci.EngCmdSetOption("Selectivity", Some("3"))))

  uci.engine_cmd()
  |> p.run("setoption name Clear Hash")
  |> should.equal(Ok(uci.EngCmdSetOption("Clear Hash", None)))

  uci.engine_cmd()
  |> p.run("setoption name NalimovPath value c:\\chess\\tb\\4;c:\\chess\\tb\\5")
  |> should.equal(
    Ok(uci.EngCmdSetOption(
      "NalimovPath",
      Some("c:\\chess\\tb\\4;c:\\chess\\tb\\5"),
    )),
  )

  uci.engine_cmd()
  |> p.run("ucinewgame")
  |> should.equal(Ok(uci.EngCmdUCINewGame))

  uci.engine_cmd()
  |> p.run("position startpos moves e2e4 h5h6")
  |> should.equal(
    Ok(uci.EngCmdPosition(uci.PositionStartPos, ["e2e4", "h5h6"])),
  )

  uci.engine_cmd()
  |> p.run("position startpos")
  |> should.equal(Ok(uci.EngCmdPosition(uci.PositionStartPos, [])))

  uci.engine_cmd()
  |> p.run("position fen 1k1r4/pp1b1R2/3q2pp/4p3/2B5/4Q3/PPP2B2/2K5 b - - 0 1")
  |> should.equal(
    Ok(
      uci.EngCmdPosition(
        uci.PositionFEN("1k1r4/pp1b1R2/3q2pp/4p3/2B5/4Q3/PPP2B2/2K5 b - - 0 1"),
        [],
      ),
    ),
  )
  uci.engine_cmd()
  |> p.run(
    "position fen r2r2k1/p1p1bppp/bpnq1n2/3p4/3P4/2QNPBP1/PP1N1PKP/R1B2R2 b - - 10 15 moves d8e8 f3e2 e8d8",
  )
  |> should.equal(
    Ok(
      uci.EngCmdPosition(
        uci.PositionFEN(
          "r2r2k1/p1p1bppp/bpnq1n2/3p4/3P4/2QNPBP1/PP1N1PKP/R1B2R2 b - - 10 15",
        ),
        ["d8e8", "f3e2", "e8d8"],
      ),
    ),
  )

  uci.engine_cmd()
  |> p.run("go movetime 1000 depth 5")
  |> should.equal(
    Ok(uci.EngCmdGo([uci.GoParamMoveTime(1000), uci.GoParamDepth(5)])),
  )

  uci.engine_cmd()
  |> p.run("go")
  |> should.equal(Ok(uci.EngCmdGo([])))

  uci.engine_cmd()
  |> p.run("stop")
  |> should.equal(Ok(uci.EngCmdStop))

  uci.engine_cmd()
  |> p.run("ponderhit")
  |> should.equal(Ok(uci.EngCmdPonderhit))

  uci.engine_cmd()
  |> p.run("quit")
  |> should.equal(Ok(uci.EngCmdQuit))
}
