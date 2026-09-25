add_executable(txn-analyzer main.cpp)

target_link_libraries(
  txn-analyzer
  PRIVATE txn_analyzer::txn_analyzer_options
          txn_analyzer::txn_analyzer_warnings
          CLI11::CLI11
          fmt::fmt
          spdlog::spdlog
          lefticus::tools
          ftxui::screen
          ftxui::dom
          ftxui::component)


txn_analyzer_configure_linker(txn-analyzer)

target_include_directories(txn-analyzer PRIVATE "${CMAKE_BINARY_DIR}/configured_files/include")

# Apply WASM-specific configuration
if(EMSCRIPTEN)
  txn_analyzer_configure_wasm_target(intro
    TITLE "txn-analyzer"
    DESCRIPTION "txn-analyzer-based terminal application"
  )
endif()
