macro(txn_analyzer_configure_linker project_name)
  set(txn_analyzer_USER_LINKER_OPTION
    "DEFAULT"
      CACHE STRING "Linker to be used")
    set(txn_analyzer_USER_LINKER_OPTION_VALUES "DEFAULT" "SYSTEM" "LLD" "GOLD" "BFD" "MOLD" "SOLD" "APPLE_CLASSIC" "MSVC")
  set_property(CACHE txn_analyzer_USER_LINKER_OPTION PROPERTY STRINGS ${txn_analyzer_USER_LINKER_OPTION_VALUES})
  list(
    FIND
    txn_analyzer_USER_LINKER_OPTION_VALUES
    ${txn_analyzer_USER_LINKER_OPTION}
    txn_analyzer_USER_LINKER_OPTION_INDEX)

  if(${txn_analyzer_USER_LINKER_OPTION_INDEX} EQUAL -1)
    message(
      STATUS
        "Using custom linker: '${txn_analyzer_USER_LINKER_OPTION}', explicitly supported entries are ${txn_analyzer_USER_LINKER_OPTION_VALUES}")
  endif()

  set_target_properties(${project_name} PROPERTIES LINKER_TYPE "${txn_analyzer_USER_LINKER_OPTION}")
endmacro()
