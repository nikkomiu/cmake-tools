set(CLANG_FORMAT_TARGET "ClangFormat" CACHE STRING "Name of the clang check target")
set(CLANG_FORMAT_DRY_TARGET "ClangFormatDry" CACHE STRING "Name of the clang check dry target")

set(CLANG_FORMAT_SUFFIX "ClangFormat" CACHE STRING "Suffix for the clang check target")
set(CLANG_DRY_SUFFIX "Dry" CACHE STRING "Suffix for the clang check dry target")

find_program(
  CLANG_FORMAT_EXECUTABLE
  NAMES clang-format
)

if(CLANG_FORMAT_EXECUTABLE)
  add_custom_target(${CLANG_FORMAT_TARGET})
  add_custom_target(${CLANG_FORMAT_DRY_TARGET})

  set_target_properties(${CLANG_FORMAT_TARGET} ${CLANG_FORMAT_DRY_TARGET} PROPERTIES FOLDER Clang)
endif()

function(clang_format)
  set(options "")
  set(oneValueArgs PKG_NAME IDE_FOLDER)
  set(multiValueArgs SOURCES)
  cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  set(FORMAT_NAME ${ARG_PKG_NAME}${CLANG_FORMAT_SUFFIX})
  set(FORMAT_DRY_NAME ${ARG_PKG_NAME}${CLANG_FORMAT_SUFFIX}${CLANG_DRY_SUFFIX})

  add_custom_target(
    ${FORMAT_DRY_NAME}
    COMMAND ${CLANG_FORMAT_EXECUTABLE}
    --Werror
    -n
    ${ARG_SOURCES}
  )

  add_custom_target(
    ${FORMAT_NAME}
    COMMAND ${CLANG_FORMAT_EXECUTABLE}
    --Werror
    -i
    ${ARG_SOURCES}
  )

  add_dependencies(${CLANG_FORMAT_TARGET} ${FORMAT_NAME})
  add_dependencies(${CLANG_FORMAT_DRY_TARGET} ${FORMAT_DRY_NAME})

  set_target_properties(${FORMAT_NAME} ${FORMAT_DRY_NAME} PROPERTIES FOLDER ${ARG_IDE_FOLDER})
endfunction()
