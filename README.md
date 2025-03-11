# The Gleam Chess Tournament

Welcome to the inaugural Unofficial Gleam Chess Tournament!

This is a friendly competition to see who can create the best chess bot in the
[Gleam](https://gleam.run) programming language. Once submissions are closed,
the tournament will be turned into a Twitch stream or YouTube video on
[my channel](https://youtube.com/IsaacHarrisHolt).

## Changelog

### 2025-03-11

- Added [birl](https://hexdocs.pm/birl/index.html),
  [gtempo](https://hexdocs.pm/gtempo/index.html) and
  [gleam_time](https://hexdocs.pm/gleam_time/index.html) as allowed libraries for all
  targets

## How does it work?

Essentially, each entry will be a Gleam web server that responds to HTTP requests sent
to a `/move` endpoint. The body will be a JSON object containing three fields:

```json
{
  "fen": "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
  "turn": "white",
  "failed_moves": ["Nf3"]
}
```

| Field          | Description                                                                                              |
| -------------- | -------------------------------------------------------------------------------------------------------- |
| `fen`          | The [FEN](https://en.wikipedia.org/wiki/Forsyth%E2%80%93Edwards_Notation) of the current board position. |
| `turn`         | The side to move. Either `"white"` or `"black"`.                                                         |
| `failed_moves` | A list of moves that your bot attempted to make for this turn, but were not legal moves.                 |

The task of parsing the FEN and returning a move is left up to you.

## Prizes

Prizes will be awarded to the top three entries. The winner will be determined by
tournament.

An additional prize will be awarded to the entry with the most interesting strategy.

- 1st place: $500, a Lucy T-shirt and a Lucy mug
- 2nd place: $300 and a T-shirt OR mug
- 3rd place: $100 and a T-shirt OR mug
- Most interesting strategy: $50 and a T-shirt OR mug

See the [Gleam shop](https://shop.gleam.run/) for more information on merch.

## Submissions

Submissions should be Gleam web servers and may use either the Erlang or JavaScript
targets. Templates for both are provided in the `erlang_template` and
`javascript_template` directories respectively.

Submissions will be pitted against each other by a client running the
[chess.js](https://github.com/jhlywa/chess.js) library for tracking and validation.

The format of the tournament is yet to be decided and will likely depend on the
number of submissions.

Submissions should be made [here](https://docs.google.com/forms/d/e/1FAIpQLSfhmo_0zxN7IDIEL6ZHZiyDaNJ2Y7_rkdt661DTaCdK2oHpSA/viewform?usp=dialog).
The submission deadline is **noon UTC on June 8th 2025**.

## How to participate

- Install [Gleam](https://gleam.run) and clone the this repository.
- Create a new directory for your submission and copy the `erlang-template` or
  `javascript-template` directory into it.
- Ensure you can run `gleam run` and the webserver starts correctly on port `8000`.
- Fill out the `move` function in `src/<target>_template/chess.gleam` with your bot's logic.
  - The function should return a `Result(String, String)` where the `Ok` variant
    is a move in [SAN](<https://en.wikipedia.org/wiki/Algebraic_notation_(chess)>)
    format. The client will validate using `chess.js`'s permissive move parser
    (see [here](https://github.com/jhlywa/chess.js?tab=readme-ov-file#parsers-permissive--strict)).
- Ensure your program compiles and runs correctly.
- Ensure you can build a Docker image for your submission using the `Dockerfile`
  provided in the template project.
- Write up a brief description of how your bot works in the `README.md` file.
- Once you're happy with your bot, submit your project [here](TODO).

## Rules

- You can participate alone or in a group.
- You may only submit one entry per person.
  - If you wish to update your entry before the tournament closes, please reach out
    to me via [Bluesky](https://bsky.app/profile/ihh.dev) or in the #chess-tournament
    channel in [my Discord](https://discord.com/invite/bWrctJ7).
- You may only use a limited set of external libraries. See [the libraries list](#libraries).
  for more information.
- You may not do any IO operations to the filesystem or network.
- FFI is not allowed.
- Your bot may not use more than the following resources. These will be enforced by Docker:
  - 2 CPU cores
  - 512mb of RAM
- Each move will be timed out after 5 seconds.
- If your bot fails three times for the same turn, either by timing out or by failing
  to make a legal move, it will forfeit the match.
- You may not modify the provided Dockerfile.
- The bots will run on Gleam 1.8.1.
  - The JavaScript bot will run on Deno, as that's what's best supported by Glen.
- You may not modify the project names (sorry, it'll break Dockerfiles!).

### Libraries

The following is a list of libraries allowed on each target. If you feel that the list
is missing something, please open an issue.

You may use any dev dependencies you wish, but they must not be included in the built
output.

#### All targets

- [gleam_stdlib](https://hexdocs.pm/gleam_stdlib/index.html)
- [gleam_http](https://hexdocs.pm/gleam_http/index.html)
- [gleam_json](https://hexdocs.pm/gleam_json/index.html)
- [gleam_time](https://hexdocs.pm/gleam_time/index.html)
- [gleam_community_maths](https://hexdocs.pm/gleam_community_maths/index.html)
- [flash](https://hexdocs.pm/flash/index.html)
- [iv](https://hexdocs.pm/iv/index.html)
- [glearray](https://hexdocs.pm/glearray/index.html)
- [snag](https://hexdocs.pm/snag/index.html)
- [birl](https://hexdocs.pm/birl/index.html)
- [gtempo](https://hexdocs.pm/gtempo/index.html)

#### Erlang

- [gleam_erlang](https://hexdocs.pm/gleam_erlang/index.html)
- [gleam_otp](https://hexdocs.pm/gleam_otp/index.html)
- [mist](https://hexdocs.pm/mist/index.html)
- [wisp](https://hexdocs.pm/wisp/index.html)

#### JavaScript

- [gleam_javascript](https://hexdocs.pm/gleam_javascript/index.html)
- [glen](https://hexdocs.pm/glen/index.html)

## Newsletter

To be kept up to date with the latest news and updates, rule changes and so forth,
subscribe to the [Gleam Chess newsletter](https://buttondown.com/gleamchess).

## Useful resources

- [The Chess Programming Wiki](https://www.chessprogramming.org/Main_Page)
