#include "chess.h"
#include "polyglot.h"

using namespace chess;
using namespace std;

class PGBuilder : public pgn::Visitor {
public:
  vector<struct BookEntry> entries;
  int elo_cutoff = 0;
  int max_elo_diff = 10000;
  int max_plies = 20;

  PGBuilder();

  virtual ~PGBuilder();

  void startPgn();

  void header(string_view key, string_view value);

  void startMoves();

  void move(string_view move, string_view comment);

  void endPgn();

  void write(ostream &strm);

private:
  Board board;


  int black_elo = -1;
  int white_elo = -1;
  int plies = 0;
  bool keep_game = true;
};
