include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


include(CheckCXXSourceCompiles)


macro(txn_analyzer_supports_sanitizers)
  # Emscripten doesn't support sanitizers
  if(EMSCRIPTEN)
    set(SUPPORTS_UBSAN OFF)
    set(SUPPORTS_ASAN OFF)
  elseif((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)

    message(STATUS "Sanity checking UndefinedBehaviorSanitizer, it should be supported on this platform")
    set(TEST_PROGRAM "int main() { return 0; }")

    # Check if UndefinedBehaviorSanitizer works at link time
    set(CMAKE_REQUIRED_FLAGS "-fsanitize=undefined")
    set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=undefined")
    check_cxx_source_compiles("${TEST_PROGRAM}" HAS_UBSAN_LINK_SUPPORT)

    if(HAS_UBSAN_LINK_SUPPORT)
      message(STATUS "UndefinedBehaviorSanitizer is supported at both compile and link time.")
      set(SUPPORTS_UBSAN ON)
    else()
      message(WARNING "UndefinedBehaviorSanitizer is NOT supported at link time.")
      set(SUPPORTS_UBSAN OFF)
    endif()
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    if (NOT WIN32)
      message(STATUS "Sanity checking AddressSanitizer, it should be supported on this platform")
      set(TEST_PROGRAM "int main() { return 0; }")

      # Check if AddressSanitizer works at link time
      set(CMAKE_REQUIRED_FLAGS "-fsanitize=address")
      set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=address")
      check_cxx_source_compiles("${TEST_PROGRAM}" HAS_ASAN_LINK_SUPPORT)

      if(HAS_ASAN_LINK_SUPPORT)
        message(STATUS "AddressSanitizer is supported at both compile and link time.")
        set(SUPPORTS_ASAN ON)
      else()
        message(WARNING "AddressSanitizer is NOT supported at link time.")
        set(SUPPORTS_ASAN OFF)
      endif()
    else()
      set(SUPPORTS_ASAN ON)
    endif()
  endif()
endmacro()

macro(txn_analyzer_setup_options)
  option(txn_analyzer_ENABLE_HARDENING "Enable hardening" ON)
  option(txn_analyzer_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    txn_analyzer_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    txn_analyzer_ENABLE_HARDENING
    OFF)

  txn_analyzer_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR txn_analyzer_PACKAGING_MAINTAINER_MODE)
    option(txn_analyzer_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(txn_analyzer_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(txn_analyzer_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(txn_analyzer_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(txn_analyzer_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(txn_analyzer_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(txn_analyzer_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(txn_analyzer_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(txn_analyzer_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(txn_analyzer_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(txn_analyzer_ENABLE_PCH "Enable precompiled headers" OFF)
    option(txn_analyzer_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(txn_analyzer_ENABLE_IPO "Enable IPO/LTO" ON)
    option(txn_analyzer_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(txn_analyzer_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(txn_analyzer_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(txn_analyzer_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(txn_analyzer_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(txn_analyzer_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(txn_analyzer_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(txn_analyzer_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(txn_analyzer_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(txn_analyzer_ENABLE_PCH "Enable precompiled headers" OFF)
    option(txn_analyzer_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      txn_analyzer_ENABLE_IPO
      txn_analyzer_WARNINGS_AS_ERRORS
      txn_analyzer_ENABLE_SANITIZER_ADDRESS
      txn_analyzer_ENABLE_SANITIZER_LEAK
      txn_analyzer_ENABLE_SANITIZER_UNDEFINED
      txn_analyzer_ENABLE_SANITIZER_THREAD
      txn_analyzer_ENABLE_SANITIZER_MEMORY
      txn_analyzer_ENABLE_UNITY_BUILD
      txn_analyzer_ENABLE_CLANG_TIDY
      txn_analyzer_ENABLE_CPPCHECK
      txn_analyzer_ENABLE_COVERAGE
      txn_analyzer_ENABLE_PCH
      txn_analyzer_ENABLE_CACHE)
  endif()

  txn_analyzer_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (txn_analyzer_ENABLE_SANITIZER_ADDRESS OR txn_analyzer_ENABLE_SANITIZER_THREAD OR txn_analyzer_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(txn_analyzer_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(txn_analyzer_global_options)
  if(txn_analyzer_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    txn_analyzer_enable_ipo()
  endif()

  txn_analyzer_supports_sanitizers()

  if(txn_analyzer_ENABLE_HARDENING AND txn_analyzer_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR txn_analyzer_ENABLE_SANITIZER_UNDEFINED
       OR txn_analyzer_ENABLE_SANITIZER_ADDRESS
       OR txn_analyzer_ENABLE_SANITIZER_THREAD
       OR txn_analyzer_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${txn_analyzer_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${txn_analyzer_ENABLE_SANITIZER_UNDEFINED}")
    txn_analyzer_enable_hardening(txn_analyzer_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(txn_analyzer_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(txn_analyzer_warnings INTERFACE)
  add_library(txn_analyzer_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  txn_analyzer_set_project_warnings(
    txn_analyzer_warnings
    ${txn_analyzer_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  include(cmake/Linker.cmake)
  # Must configure each target with linker options, we're avoiding setting it globally for now

  if(NOT EMSCRIPTEN)
    include(cmake/Sanitizers.cmake)
    txn_analyzer_enable_sanitizers(
      txn_analyzer_options
      ${txn_analyzer_ENABLE_SANITIZER_ADDRESS}
      ${txn_analyzer_ENABLE_SANITIZER_LEAK}
      ${txn_analyzer_ENABLE_SANITIZER_UNDEFINED}
      ${txn_analyzer_ENABLE_SANITIZER_THREAD}
      ${txn_analyzer_ENABLE_SANITIZER_MEMORY})
  endif()

  set_target_properties(txn_analyzer_options PROPERTIES UNITY_BUILD ${txn_analyzer_ENABLE_UNITY_BUILD})

  if(txn_analyzer_ENABLE_PCH)
    target_precompile_headers(
      txn_analyzer_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(txn_analyzer_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    txn_analyzer_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(txn_analyzer_ENABLE_CLANG_TIDY)
    txn_analyzer_enable_clang_tidy(txn_analyzer_options ${txn_analyzer_WARNINGS_AS_ERRORS})
  endif()

  if(txn_analyzer_ENABLE_CPPCHECK)
    txn_analyzer_enable_cppcheck(${txn_analyzer_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(txn_analyzer_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    txn_analyzer_enable_coverage(txn_analyzer_options)
  endif()

  if(txn_analyzer_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(txn_analyzer_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(txn_analyzer_ENABLE_HARDENING AND NOT txn_analyzer_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR txn_analyzer_ENABLE_SANITIZER_UNDEFINED
       OR txn_analyzer_ENABLE_SANITIZER_ADDRESS
       OR txn_analyzer_ENABLE_SANITIZER_THREAD
       OR txn_analyzer_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    txn_analyzer_enable_hardening(txn_analyzer_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
