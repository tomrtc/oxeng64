macro(oxeng64_configure_linker project_name)
  set(oxeng64_USER_LINKER_OPTION
    "DEFAULT"
      CACHE STRING "Linker to be used")
    set(oxeng64_USER_LINKER_OPTION_VALUES "DEFAULT" "SYSTEM" "LLD" "GOLD" "BFD" "MOLD" "SOLD" "APPLE_CLASSIC" "MSVC")
  set_property(CACHE oxeng64_USER_LINKER_OPTION PROPERTY STRINGS ${oxeng64_USER_LINKER_OPTION_VALUES})
  list(
    FIND
    oxeng64_USER_LINKER_OPTION_VALUES
    ${oxeng64_USER_LINKER_OPTION}
    oxeng64_USER_LINKER_OPTION_INDEX)

  if(${oxeng64_USER_LINKER_OPTION_INDEX} EQUAL -1)
    message(
      STATUS
        "Using custom linker: '${oxeng64_USER_LINKER_OPTION}', explicitly supported entries are ${oxeng64_USER_LINKER_OPTION_VALUES}")
  endif()

  set_target_properties(${project_name} PROPERTIES LINKER_TYPE "${oxeng64_USER_LINKER_OPTION}")
endmacro()
