#include "argparse.h"
#include "chess.h"
#include "pg_builder.h"
#include "polyglot.h"
#include "tinylogger.h"
#include <cstdlib>
#include <fstream>

int build(string pgn, string bin, int max_plies, int elo_cutoff,
          int max_elo_diff) {
  ifstream pgn_strm(pgn);
  ofstream bin_strm(bin, ios::binary);

  if (!pgn_strm.is_open()) {
    LOG_ERROR("could not open file %s\n", pgn.c_str());
    return EXIT_FAILURE;
  }
  if (!bin_strm.is_open()) {
    LOG_ERROR("could not open file %s\n", bin.c_str());
    return EXIT_FAILURE;
  }

  PGBuilder pg_builder;
  pg_builder.elo_cutoff = elo_cutoff;
  pg_builder.max_elo_diff = max_elo_diff;
  pg_builder.max_plies = max_plies;

  pgn::StreamParser parser(pgn_strm);
  auto error = parser.readGames(pg_builder);

  if (error) {
    LOG_ERROR("could not parse pgn\n", error.message().c_str());
    return EXIT_FAILURE;
  }

  // Sort the entries. This is formally part of the polyglot spec.
  sort(pg_builder.entries.begin(), pg_builder.entries.end());
  // Not sure if reducing is part of the spec, but why not. It saves some
  // space.
  auto reduced_entries = reduce_to_normal_form(pg_builder.entries);
  pg_builder.entries.clear();

  LOG_DEBUG("writing %d entries\n", reduced_entries.size());

  // Finally, write it to stream
  write_pg_file(bin_strm, reduced_entries);

  bin_strm.close();
  pgn_strm.close();

  return EXIT_SUCCESS;
}

int codegen(string bin, string out, uint64_t min_position_frequency_per_million,
            uint16_t min_move_frequency_per_million) {
  ifstream bin_strm(bin, ios::binary);
  ofstream out_strm(out);

  if (!bin_strm.is_open()) {
    LOG_ERROR("could not open file %s\n", bin.c_str());
    return EXIT_FAILURE;
  }
  if (!out_strm.is_open()) {
    LOG_ERROR("could not open file %s\n", out.c_str());
    return EXIT_FAILURE;
  }

  auto entries = read_pg_file(bin_strm);
  if (entries.size() == 0) {
    LOG_ERROR("polyglot file has no entries\n");
    return EXIT_FAILURE;
  }

  sort(entries.begin(), entries.end());
  auto reduced_entries = reduce_to_normal_form(entries);
  entries.clear();

  LOG_DEBUG("got %d reduced entries, filtering them down\n",
            reduced_entries.size());

  // We're going to create groups of entries:
  // Each group correspond to a single position. Entries in the group are
  // weighted moves for the position.
  // Then, we'll figure out which positions to keep by doing a frequency
  // cutoff. The frequency of the position is determined by the total weight
  // of the group.

  // The first step is to group the entries.
  vector<vector<struct BookEntry *>> groups;
  {
    auto &group_key = reduced_entries[0].key;
    vector<struct BookEntry *> curr_group;
    for (auto &be : reduced_entries) {
      if (be.key != group_key) {
        // New group. Copy the group and push it.
        groups.push_back(curr_group);

        group_key = be.key;
        curr_group.clear();
      }

      curr_group.push_back(&be);
    }
    // Don't forget the last group.
    groups.push_back(curr_group);
  }

  LOG_DEBUG("got %d reduced groups\n", reduced_entries.size());

  // Get the max frequency. This is used later when we filter out
  // positions.
  // We also find the frequencies for each group/position by iterating over the
  // groups and summing up the weight of its entries.
  // We could've done all of this in one pass earlier, but it would be a lot
  // harder to read for being only slightly more efficient.
  vector<uint64_t> position_frequencies;
  vector<uint16_t> max_weights;
  uint64_t max_position_frequency = 0;
  {
    // No need for resizing later.
    position_frequencies.resize(groups.size());
    max_weights.resize(groups.size());

    for (int i = 0; i < groups.size(); i++) {
      auto &group = groups[i];
      uint64_t position_frequency = 0;
      max_weights[i] = 0;
      for (auto be : group) {
        position_frequency += be->weight;
        max_weights[i] = max(max_weights[i], be->weight);
      }
      max_position_frequency = max(max_position_frequency, position_frequency);
      position_frequencies[i] = position_frequency;
    }
  }
  LOG_DEBUG("max position frequency is %llu\n", max_position_frequency);
  LOG_DEBUG("position cutoff will be %llu\n",
            min_position_frequency_per_million * max_position_frequency /
                1000000);

  // We begin writing to the file:
  // - Iterate through each group
  // - Ignore infrequent positions
  // - Write the group
  {
    uint32_t groups_kept = 0;
    uint32_t moves_kept = 0;
    out_strm << "pub const table = [";
    for (int i = 0; i < groups.size(); i++) {
      auto &group = groups[i];
      uint64_t position_frequency_per_million =
          (position_frequencies[i] * 1000000) / max_position_frequency;
      // Skip this position altogether if it's really infrequent, relative to
      // the most frequent.
      if (position_frequency_per_million < min_position_frequency_per_million) {
        continue;
      } else {
        groups_kept++;
      }

      // Now emit the group.
      out_strm << "#(0x" << hex << group[0]->key << ",[";
      struct BookEntry *be;
      // Iterate through all of the group except last
      for (int j = 0; j < group.size() - 1; j++) {
        be = group[j];
        uint64_t move_frequency_per_million =
            (group[j]->weight * 1000000) / max_weights[i];
        if (move_frequency_per_million < min_move_frequency_per_million) {
          continue;
        } else {
          moves_kept++;
        }

        out_strm << "#(0x" << hex << be->move << "," << "0x" << hex
                 << be->weight << "),";
      }

      be = group[group.size() - 1];
      // Last one has no comma in the list of moves. Over a large amount of
      // tables, this is bound to save a few KB to a few MB.
      out_strm << "#(0x" << hex << be->move << "," << "0x" << hex << be->weight
               << ")";
      // If this is the last group, we'll add the trailing comma (to the outer
      // list). This will mean we'll have only one unnecessary comma for this
      // file, which is acceptable.
      out_strm << "]),";
    }
    out_strm << "]" << endl;
    LOG_DEBUG("kept %ld groups\n", groups_kept);
    LOG_DEBUG("kept %ld moves\n", moves_kept);
  }

  out_strm.close();
  bin_strm.close();

  return EXIT_SUCCESS;
}

int merge(vector<string> bins, string out_bin) {
  ofstream out_strm(out_bin, ios::binary);
  if (!out_strm) {
    LOG_ERROR("could not open file %s\n", out_bin.c_str());
    return EXIT_FAILURE;
  }
  vector<ifstream> bin_strms;
  for (auto &bin : bins) {
    ifstream bin_strm(bin);
    if (!bin_strm) {
      LOG_ERROR("could not open file %s\n", bin.c_str());
      return EXIT_FAILURE;
    }
    bin_strms.emplace_back(std::move(bin_strm));
  }

  // Load all entries and then sort them
  // TODO: Do a k-way merge instead. It should be faster
  vector<struct BookEntry> all_entries;
  for (auto &bin_strm : bin_strms) {
    auto entries = read_pg_file(bin_strm);
    all_entries.insert(all_entries.end(), entries.begin(), entries.end());
  }

  LOG_DEBUG("read a total of %d entries\n", all_entries.size());
  sort(all_entries.begin(), all_entries.end());
  auto reduced_entries = reduce_to_normal_form(all_entries);
  all_entries.clear();

  LOG_DEBUG("reduced to %d entries\n", reduced_entries.size());

  LOG_DEBUG("writing to file\n");
  write_pg_file(out_strm, reduced_entries);

  for (auto &bin_strm : bin_strms) {
    bin_strm.close();
  }
  out_strm.close();
  return EXIT_SUCCESS;
}

int main(int argc, char **argv) {
  argparse::ArgumentParser build_command("build");
  build_command.add_description("Generate Polyglot file from PGN");
  build_command.add_argument("--pgn").required().help("PGN file to load from");
  build_command.add_argument("--bin")
      .default_value("polyglot.bin")
      .help("Polyglot file to output to");
  build_command.add_argument("--max-plies")
      .default_value(16)
      .scan<'i', int>()
      .help("Max plies to take from each game");
  build_command.add_argument("--elo-cutoff")
      .default_value(2200)
      .scan<'i', int>()
      .help("If ELO headers are present in PGN, the minimum ELO to keep games");
  build_command.add_argument("--max-elo-diff")
      .default_value(200)
      .scan<'i', int>()
      .help("If ELO headers are present in PGN, the maximum ELO difference "
            "between players to keep games. This is to prevent, e.g. friendly "
            "games, from being processed");

  argparse::ArgumentParser codegen_command("codegen");
  codegen_command.add_description("Generate gleam code");
  codegen_command.add_argument("--bin").required().help(
      "Polyglot file to read from");
  codegen_command.add_argument("--output").required().help("Codegen output");
  codegen_command.add_argument("--min-pos-freq-per-mill")
      .default_value(1000)
      .scan<'i', int32_t>()
      .help("The minimum frequency per million of a position to keep, relative "
            "to the maximum frequency of positions. For example, if the "
            "starting position appears 1 million times and is the most "
            "frequent position, then setting this to N will filter out "
            "positions that appeared less than N times.");
  codegen_command.add_argument("--min-move-freq-per-mill")
      .default_value(10000)
      .scan<'i', int32_t>()
      .help("The minimum frequency per million of a move to keep, relative "
            "to the maximum frequency of moves on a given position. For "
            "example, if a position contained a move with 1 million weight, "
            "then setting this to N will filter out moves for this position "
            "that appeared less than N times.");

  argparse::ArgumentParser merge_command("merge");
  merge_command.add_description("Merge Polyglot files");
  merge_command.add_argument("--bins").nargs(1, 256).required().help(
      "Polyglot files to merge");
  merge_command.add_argument("--output").required().help("File to merge into");

  int verbosity = 0;
  argparse::ArgumentParser program("polyglot-operator");
  program.add_subparser(build_command);
  program.add_subparser(codegen_command);
  program.add_subparser(merge_command);
  program.add_argument("-v", "--verbose")
      .action([&](const auto &) { ++verbosity; })
      .append()
      .default_value(false)
      .implicit_value(true)
      .nargs(0);

  try {
    program.parse_args(argc, argv);
  } catch (const std::exception &err) {
    cerr << err.what() << endl;
    cerr << program;
    return EXIT_FAILURE;
  }

  switch (verbosity) {
  case 1:
    SET_LOG_LEVEL(tinylogger::LogLevel::Debug);
    break;
  case 0:
  default:
    SET_LOG_LEVEL(tinylogger::LogLevel::Info);
    break;
  }

  if (program.is_subcommand_used(build_command)) {
    string pgn = build_command.get("--pgn");
    string bin = build_command.get("--bin");
    auto elo_cutoff = build_command.get<int>("--elo-cutoff");
    auto max_elo_diff = build_command.get<int>("--max-elo-diff");
    auto max_plies = build_command.get<int>("--max-plies");
    return build(pgn, bin, max_plies, elo_cutoff, max_elo_diff);
  } else if (program.is_subcommand_used(codegen_command)) {
    string bin = codegen_command.get("--bin");
    string out = codegen_command.get("--output");
    auto min_position_frequency_per_million =
        codegen_command.get<int32_t>("--min-pos-freq-per-mill");
    auto min_move_frequency_per_million =
        codegen_command.get<int32_t>("--min-move-freq-per-mill");
    return codegen(bin, out, min_position_frequency_per_million,
                   min_move_frequency_per_million);
  } else if (program.is_subcommand_used(merge_command)) {
    auto bins = merge_command.get<vector<string>>("--bins");
    string out = merge_command.get("--output");
    return merge(bins, out);
  } else {
    cerr << program << endl;
    cerr << "Need subcommand" << endl;
    return EXIT_FAILURE;
  }
}
