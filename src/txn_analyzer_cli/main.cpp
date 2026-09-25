#include <cstdlib>
#include <exception>

#include <CLI/CLI.hpp>
#include <fmt/base.h>
#include <fmt/format.h>
#include <spdlog/spdlog.h>

#include <internal_use_only/config.hpp>

int main(int argc, const char **argv)
{
  try {
    CLI::App app{ fmt::format(
      "{} version {}",
      txn_analyzer::cmake::project_name,
      txn_analyzer::cmake::project_version) };

    bool show_version = false;
    app.add_flag("--version", show_version, "Show version information");

    CLI11_PARSE(app, argc, argv);

    if (show_version) {
      fmt::print("{}\n", txn_analyzer::cmake::project_version);
      return EXIT_SUCCESS;
    }

    fmt::print("Transaction Stream Analyzer\n");
    return EXIT_SUCCESS;
  } catch (const std::exception &e) {
    spdlog::error("Unhandled exception: {}", e.what());
    return EXIT_FAILURE;
  }
}