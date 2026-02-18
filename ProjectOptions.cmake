include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


include(CheckCXXSourceCompiles)


macro(oxeng64_supports_sanitizers)
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

macro(oxeng64_setup_options)
  option(oxeng64_ENABLE_HARDENING "Enable hardening" ON)
  option(oxeng64_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    oxeng64_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    oxeng64_ENABLE_HARDENING
    OFF)

  oxeng64_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR oxeng64_PACKAGING_MAINTAINER_MODE)
    option(oxeng64_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(oxeng64_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(oxeng64_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(oxeng64_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(oxeng64_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(oxeng64_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(oxeng64_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(oxeng64_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(oxeng64_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(oxeng64_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(oxeng64_ENABLE_PCH "Enable precompiled headers" OFF)
    option(oxeng64_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(oxeng64_ENABLE_IPO "Enable IPO/LTO" ON)
    option(oxeng64_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(oxeng64_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(oxeng64_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(oxeng64_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(oxeng64_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(oxeng64_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(oxeng64_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(oxeng64_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(oxeng64_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(oxeng64_ENABLE_PCH "Enable precompiled headers" OFF)
    option(oxeng64_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      oxeng64_ENABLE_IPO
      oxeng64_WARNINGS_AS_ERRORS
      oxeng64_ENABLE_SANITIZER_ADDRESS
      oxeng64_ENABLE_SANITIZER_LEAK
      oxeng64_ENABLE_SANITIZER_UNDEFINED
      oxeng64_ENABLE_SANITIZER_THREAD
      oxeng64_ENABLE_SANITIZER_MEMORY
      oxeng64_ENABLE_UNITY_BUILD
      oxeng64_ENABLE_CLANG_TIDY
      oxeng64_ENABLE_CPPCHECK
      oxeng64_ENABLE_COVERAGE
      oxeng64_ENABLE_PCH
      oxeng64_ENABLE_CACHE)
  endif()

  oxeng64_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (oxeng64_ENABLE_SANITIZER_ADDRESS OR oxeng64_ENABLE_SANITIZER_THREAD OR oxeng64_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(oxeng64_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(oxeng64_global_options)
  if(oxeng64_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    oxeng64_enable_ipo()
  endif()

  oxeng64_supports_sanitizers()

  if(oxeng64_ENABLE_HARDENING AND oxeng64_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR oxeng64_ENABLE_SANITIZER_UNDEFINED
       OR oxeng64_ENABLE_SANITIZER_ADDRESS
       OR oxeng64_ENABLE_SANITIZER_THREAD
       OR oxeng64_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${oxeng64_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${oxeng64_ENABLE_SANITIZER_UNDEFINED}")
    oxeng64_enable_hardening(oxeng64_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(oxeng64_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(oxeng64_warnings INTERFACE)
  add_library(oxeng64_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  oxeng64_set_project_warnings(
    oxeng64_warnings
    ${oxeng64_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  include(cmake/Linker.cmake)
  # Must configure each target with linker options, we're avoiding setting it globally for now

  if(NOT EMSCRIPTEN)
    include(cmake/Sanitizers.cmake)
    oxeng64_enable_sanitizers(
      oxeng64_options
      ${oxeng64_ENABLE_SANITIZER_ADDRESS}
      ${oxeng64_ENABLE_SANITIZER_LEAK}
      ${oxeng64_ENABLE_SANITIZER_UNDEFINED}
      ${oxeng64_ENABLE_SANITIZER_THREAD}
      ${oxeng64_ENABLE_SANITIZER_MEMORY})
  endif()

  set_target_properties(oxeng64_options PROPERTIES UNITY_BUILD ${oxeng64_ENABLE_UNITY_BUILD})

  if(oxeng64_ENABLE_PCH)
    target_precompile_headers(
      oxeng64_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(oxeng64_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    oxeng64_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(oxeng64_ENABLE_CLANG_TIDY)
    oxeng64_enable_clang_tidy(oxeng64_options ${oxeng64_WARNINGS_AS_ERRORS})
  endif()

  if(oxeng64_ENABLE_CPPCHECK)
    oxeng64_enable_cppcheck(${oxeng64_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(oxeng64_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    oxeng64_enable_coverage(oxeng64_options)
  endif()

  if(oxeng64_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(oxeng64_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(oxeng64_ENABLE_HARDENING AND NOT oxeng64_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR oxeng64_ENABLE_SANITIZER_UNDEFINED
       OR oxeng64_ENABLE_SANITIZER_ADDRESS
       OR oxeng64_ENABLE_SANITIZER_THREAD
       OR oxeng64_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    oxeng64_enable_hardening(oxeng64_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
