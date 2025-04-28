#include "argparse.h"
#include "chess.h"
#include "pg_builder.h"
#include "polyglot.h"
#include "tinylogger.h"
#include "util.h"
#include <cstdlib>
#include <fstream>

int build(string pgn, string bin, int elo_cutoff, int max_elo_diff) {
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

int codegen(string bin, string out) {
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

  LOG_DEBUG("generating %d entries into code\n", reduced_entries.size());

  auto &group_key = reduced_entries[0].key;
  vector<struct BookEntry> group;
  out_strm << "pub fn move_lookup(x) {" << endl;
  out_strm << "case x {" << endl;
  for (auto &be : reduced_entries) {
    if (be.key != group_key) {
      // New group. Emit the current group and set new group
      out_strm << "0x" << hex << swap64(be.key) << "->[";
      // Iterate through all of the group except last
      for (int j = 0; j < group.size() - 1; j++) {
        auto &ge = group[j];
        // TODO: Consider adding weight
        out_strm << "0x" << hex << swap16(ge.move) << ",";
      }

      // Last one has no comma
      // TODO: Consider adding weight
      out_strm << "0x" << hex << swap16(group[group.size() - 1].move);
      out_strm << "]" << endl;

      group_key = be.key;
      group.clear();
    }

    group.push_back(be);
  }

  out_strm << "_->[]" << endl; // catch-all
  out_strm << "}" << endl;     // end case
  out_strm << "}" << endl;     // end function

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

  argparse::ArgumentParser merge_command("merge");
  merge_command.add_description("Merge Polyglot files");
  merge_command.add_argument("--bins").nargs(1, 128).required().help(
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
    return build(pgn, bin, elo_cutoff, max_elo_diff);
  } else if (program.is_subcommand_used(codegen_command)) {
    string bin = codegen_command.get("--bin");
    string out = codegen_command.get("--output");
    return codegen(bin, out);
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
