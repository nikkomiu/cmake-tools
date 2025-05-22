set(CLANG_CHECK_TARGET "ClangCheck" CACHE STRING "Name of the clang check target")
set(CLANG_CHECK_DRY_TARGET "ClangCheckDry" CACHE STRING "Name of the clang check dry target")

set(CLANG_CHECK_SUFFIX "ClangCheck" CACHE STRING "Suffix for the clang check target")
set(CLANG_DRY_SUFFIX "Dry" CACHE STRING "Suffix for the clang check dry target")

find_program(
  CLANG_CHECK_EXECUTABLE
  NAMES clang-check
)

if(CLANG_CHECK_EXECUTABLE)
  add_custom_target(${CLANG_CHECK_TARGET})
  add_custom_target(${CLANG_CHECK_DRY_TARGET})

  set_target_properties(${CLANG_CHECK_TARGET} ${CLANG_CHECK_DRY_TARGET} PROPERTIES FOLDER Clang)
endif()

function(clang_check)
  set(options "")
  set(oneValueArgs PKG_NAME IDE_FOLDER)
  set(multiValueArgs SOURCES)
  cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  if(NOT CLANG_CHECK_EXECUTABLE)
    message(STATUS "Binary for 'clang-check' not found. Not adding target to '${ARG_PKG_NAME}'.")
    return()
  endif()

  set(CHECK_NAME ${ARG_PKG_NAME}${CLANG_CHECK_SUFFIX})
  set(CHECK_DRY_NAME ${ARG_PKG_NAME}${CLANG_CHECK_SUFFIX}${CLANG_DRY_SUFFIX})

  add_custom_target(
    ${CHECK_NAME}
    COMMAND ${CLANG_CHECK_EXECUTABLE}
    -analyze
    -p .
    --fixit
    ${ARG_SOURCES}
  )

  add_custom_target(
    ${CHECK_DRY_NAME}
    COMMAND ${CLANG_CHECK_EXECUTABLE}
    -analyze
    -p .
    ${ARG_SOURCES}
  )

  add_dependencies(${CLANG_CHECK_TARGET} ${CHECK_NAME})
  add_dependencies(${CLANG_CHECK_DRY_TARGET} ${CHECK_DRY_NAME})

  set_target_properties(${CHECK_NAME} ${CHECK_DRY_NAME} PROPERTIES FOLDER ${ARG_IDE_FOLDER})
endfunction()
