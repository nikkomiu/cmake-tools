set(CLANG_TIDY_TARGET "ClangTidy" CACHE STRING "Name of the clang check target")
set(CLANG_TIDY_DRY_TARGET "ClangTidyDry" CACHE STRING "Name of the clang check dry target")

set(CLANG_TIDY_SUFFIX "ClangTidy" CACHE STRING "Suffix for the clang check target")
set(CLANG_DRY_SUFFIX "Dry" CACHE STRING "Suffix for the clang check dry target")

find_program(
  CLANG_TIDY_EXECUTABLE
  NAMES clang-tidy
)

if(CLANG_TIDY_EXECUTABLE)
  add_custom_target(${CLANG_TIDY_TARGET})
  add_custom_target(${CLANG_TIDY_DRY_TARGET})

  set_target_properties(${CLANG_TIDY_TARGET} ${CLANG_TIDY_DRY_TARGET} PROPERTIES FOLDER Clang)
endif()

function(clang_tidy)
  set(options "")
  set(oneValueArgs PKG_NAME IDE_FOLDER)
  set(multiValueArgs SOURCES)
  cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  set(TIDY_NAME ${ARG_PKG_NAME}${CLANG_TIDY_SUFFIX})
  set(TIDY_DRY_NAME ${ARG_PKG_NAME}${CLANG_TIDY_SUFFIX}${CLANG_DRY_SUFFIX})

  if(NOT CLANG_TIDY_EXECUTABLE)
    return()
  endif()

  add_custom_target(
    ${TIDY_DRY_NAME}
    COMMAND ${CLANG_TIDY_EXECUTABLE}
    -p ${CMAKE_BINARY_DIR}
    -checks=*
    -header-filter=""
    -warnings-as-errors=*
    -quiet
    ${ARG_SOURCES}
  )

  add_custom_target(
    ${TIDY_NAME}
    COMMAND ${CLANG_TIDY_EXECUTABLE}
    -p ${CMAKE_BINARY_DIR}
    -checks=*
    -header-filter=""
    -warnings-as-errors=*
    -quiet
    -fix
    ${ARG_SOURCES}
  )

  add_dependencies(${CLANG_TIDY_TARGET} ${TIDY_NAME})
  add_dependencies(${CLANG_TIDY_DRY_TARGET} ${TIDY_DRY_NAME})

  set_target_properties(${TIDY_NAME} ${TIDY_DRY_NAME} PROPERTIES FOLDER ${ARG_IDE_FOLDER})
endfunction()
