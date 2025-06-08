# **gnomeschesser**

[gnomeschesser](https://github.com/tonyd33/gnomeschesser) is a classical chess engine using standard techniques, implemented in Gleam. It uses minimax and employs a variety of techniques to reduce the search space.

### Search:

- [Alpha beta pruning](https://www.chessprogramming.org/Alpha-Beta)
- [Iterative deepening](https://www.chessprogramming.org/Iterative_Deepening)
- [Quiescence search](https://www.chessprogramming.org/Quiescence_Search)
- [Move ordering](https://www.chessprogramming.org/Move_Ordering)
    - We order our moves using:
        1. [PV-move](https://www.chessprogramming.org/PV-Move)
            1. Using [Hash Moves](https://www.chessprogramming.org/Hash_Move) if it exists, otherwise we try [Internal Iterative Deepening](https://www.chessprogramming.org/Internal_Iterative_Deepening)
        2. [Most Valuable Victim - Least Valuable Attacker](https://www.chessprogramming.org/MVV-LVA) for non-quiet moves
        3. [History Heuristic](https://www.chessprogramming.org/History_Heuristic) for quiet moves
        4. [Piece-Square Tables](https://www.chessprogramming.org/Piece-Square_Tables) to resolve any ties
- [Transposition tables](https://www.chessprogramming.org/Transposition_Table)
    - Indexed by [zobrist hashes](https://www.chessprogramming.org/Zobrist_Hashing)
- [Late move reduction](https://www.chessprogramming.org/Late_Move_Reductions)
- [Null move pruning](https://www.chessprogramming.org/Null_Move_Pruning)
    - We do this very aggressively, using the game phase to determine the cut-off
    - This makes us pretty vulnerable to zugzwang, but we decided to accept that tradeoff
- [Null move reduction](https://www.chessprogramming.org/Null_Move_Reductions)
- [Principal Variation Search](https://www.chessprogramming.org/Principal_Variation_Search)
- [Aspiration windows](https://www.chessprogramming.org/Aspiration_Windows)
- Opening table
    - We used the data from <data>, and wrote a program to filter out unique positions then convert from polyglot .bin format to a big gleam dict. This data is then passed around the search.

### Evaluation:

- [Material](https://www.chessprogramming.org/Material) score with values taken from Stockfish
- [Piece-Square Tables](https://www.chessprogramming.org/Piece-Square_Tables) encoding preferred positions of pieces
- [Mobility](https://www.chessprogramming.org/Mobility) scores to encourage searching for advantages through board control
- [Pawn structure](https://www.chessprogramming.org/Pawn_Structure) to enable strong pawn positions
    - Pawn shield for when the king is castled
    - Supported pawns, doubled pawns, etc.
    - Passed pawns (important for endgame)
- [Tapered](https://www.chessprogramming.org/Tapered_Eval) midgame to endgame evaluation, based on game phase
    - Phase is calculated based on the total non-pawn material scores
- [Check](https://www.chessprogramming.org/Check)/[Pin](https://www.chessprogramming.org/Pin) penalty
    - We add a small penalty if a piece is pinned, scaled based on its material value
    - We add a penalty if the king is in check, with a bigger penalty for a double check
- [Tempo](https://www.chessprogramming.org/Tempo) bonus
    - couldn’t hurt

Given that calculating these evaluation terms can be expensive, our engine incrementally updates many of these terms so that, while searching, we have access to evaluation at a low cost.

### Data Representations:

- Game
    - Board is a dictionary of square → pieces
    - We also hold all the other data contained in FEN
    - Contains bitboard information for pawns specifically
    - Also maintains king checks and pins
- Square
    - Square is an integer in [0x88](https://www.chessprogramming.org/0x88) format
        - This can take advantage of off-the-board checks with 0x88 squares easily
- Move
    - From, to, and promotion
    - We also contain extra context for the piece being moved, captures (if it exists), whether it’s a castle move.
    - We use phantom types to distinguish between pseudo moves and legal moves, though this is rarely used as we perform a full legal move generation anyways
        - I just wanted to have a phantom type

### Optimizations:

On the topic of optimization, we pre-computed values and encoded them as constants in case expressions, which end up more performant than array and dictionary lookups. For example, the squares that each piece can move to at each square are stored in a large case expression. Other data are stored in a similar fashion.

- We also incrementally update data in our game state for optimization.
    - [Zobrist hashes](https://www.chessprogramming.org/Zobrist_Hashing)
    - King checks/pins
    - Bitboards
    - Bishop/Knight count for cheaper checking of insufficient material endgames
    - Material count
- For threefold repetition, we can clear the game history when the half-move counter is 0, as that indicates an irreversible move
- A lot of other stuff we can’t remember, there’s a decent amount that are Gleam crimes

### State Implementation details:

While traversing the search tree, we must maintain and update values like the transposition table, and as a luxury, search statistics (e.g. number of beta-cutoffs, transposition table cache hits, etc.). In Gleam, where variables are immutable, this is cumbersome: functions would have to accept extraneous arguments and return extraneous values, making the code noisy and hard-to-read. For example, it would be strange for a function that does a transposition table lookup to accept and return statistics just because it needs to increment a statistic.

The solution was using the State monad, a popular construct in other functional programming languages to simulate stateful code. This works well in Gleam with its `use` syntax and transforms code like this:

```gleam
/// Get a value in the transposition table
fn tt_get(
	tt: TranspositionTable,
	key: Key,
	stats: Stats
) -> #(Result(Entry, Nil), Stats) {
	case tt.get(tt, key) {
		Ok(entry) -> #(
			Ok(entry),
			Stats(..stats, hits: stats.hits + 1)
		)
		Error(Nil) -> #(
			Error(Nil),
			Stats(..stats, misses: stats.misses + 1)
		)
	}
}
```

...into code like this:

```gleam
fn tt_get(
	tt: TranspositionTable,
	key: Key
) -> State(Stats, Entry) {
	use stats: Stats <- state.do(state.get_state())
	let entry = tt.get(tt, key)
	use _ <- state.do(state.put(case entry {
		Ok(_) -> State(..stats, hits: stats.hits + 1)
		Error(Nil) -> State(..stats, misses: stats.misses + 1)
	}))
	state.return(entry)
}
```

### Actor/Search Management Implementation Details:

Being able to stop the engine effectively while it’s searching and preserving any progress it’s made is critical. To that end, we considered a few options: we may poll frequently to check if a stop condition has been met, or we may send updates to an intermediary actor that sends the most recent value upon a signal.

We ended up choosing the former. We use a layered architecture, with the outermost layer around the engine, Blake, an actor that serves as the main shell to interact with our engine. This allows us to create multiple entrypoints to our engine, including the HTTP entrypoint and a UCI entrypoint for compatibility with existing tooling.

Blake keeps track of the game history, tablebases, and controls the search, which is done on another actor, Donovan.

Donovan is our search thread and is capable of receiving only a “start search” and “stop search” command. Donovan only keeps track of state that’s used in the search: the transposition table, history heuristic, statistics. As the transposition table can be large, Donovan never communicates its state to other actors, only communicating evaluations. It’s for this reason that Donovan is never killed – we would lose the entire transposition table.

We turn to discussing how Donovan is able to receive the “stop search” command, respond in a timely fashion, yet not forcibly be killed and preserve its state.

### Search Timing Implementation Details:

By regularly sprinkling “interruption checks” as well as performing strategic “checkpoints” throughout the search, we can be pretty confident that the search can be terminated in time without losing much progress. In practice, with Gleam’s `use` syntax, it gives us declarative code like this:

```gleam
fn iterative_deepening(game, alpha, beta, depth) {
	use <- interruptable
	use evaluation <- do(minimax(game, alpha, beta, depth))
	use <- checkpoint(evaluation)
	iterative_deepening(game, alpha, beta, depth + 1)
}
```

This is implemented by storing an “interrupt checker” within the State monad mentioned earlier, and calling upon it and returning an error if there’s an interrupt:

```gleam
fn interruptable(f) {
	use interrupt <- state.do(state.get_state())
	case interrupt() {
		True -> state.return(Error(Nil))
		False -> f()
	}
}
```

The interrupt checker simply checks if it has received a stop command on a subject.

```gleam
let interrupt = fn() {
	case process.receive(recv, 0) {
		Ok(Stop) -> True
		_ -> False
	}
}
```

Polling for messages regularly adds surprisingly little overhead and, with interrupt checks properly sprinkled throughout the search, it makes stopping the search incredibly responsive at relatively little cost.

As for checkpointing, it’s likely simpler than you might think:

```gleam
pub fn checkpoint(a_chkpt: a, f: fn() -> InterruptableState(s, a)) {
  use ra <- state.do(f())

  case ra {
    Ok(a) -> state.return(Ok(a))
    Error(Nil) -> state.return(Ok(a_chkpt))
  }
}
```

For more details, take a look at the `interruptable_state.gleam` and `state.gleam` files.

### Tooling:

We built a chess tui and a web UI to test against the web interface initially. Then we built a UCI adapter to connect to the web interface, in order to use existing chess tooling. We eventually built a full UCI parser into our engine, as the design of UCI required us to rework the way our program communicates with itself.

We used fastchess to run SPRT tests on our changes, which allowed us to be confident that the change is a statistical improvement. We also have automated CI to run regression SPRT tests, and positional tests against Bratko-Kopec, Win At Chess, and many other positions.

We also created a separate gleam project with gnomeschesser as a dependency, which contained scripts using glychee (and later our own benchee binding), in order to profile sprt and overall search speeds.

### Multithreading:

It ended up being difficult to make use of both threads. PVS splitting seemed the most promising, we had some attempts but we ended up not going through with it. We also tried Lazy SMP, but the communication overhead in accessing a shared transposition table through message passing ends up about equal in strength compared to a single-threaded search.
