set(TEST_DIR_NAME "tests" CACHE STRING "Directory for the test code")
set(COVERAGE_DIR_NAME "coverage" CACHE STRING "Directory for the test code")

set(TEST_TARGET_NAME "TestAll" CACHE STRING "Name of the testing target")
set(COVER_TARGET_NAME "CoverAll" CACHE STRING "Name of the test coverage target")
set(TEST_TARGET_SUFFIX "Test" CACHE STRING "Suffix for the testing target")
set(COVER_TARGET_SUFFIX "Cover" CACHE STRING "Suffix for the testing target")

add_custom_target(${TEST_TARGET_NAME})

if (WITH_COVERAGE)
  add_custom_target(${COVER_TARGET_NAME})
endif()

function(test_pkg)
  set(options "")
  set(oneValueArgs PKG_NAME TEST_PREFIX IDE_FOLDER)
  set(multiValueArgs SOURCES PUBLIC_LINK_LIBRARIES PRIVATE_LINK_LIBRARIES)
  cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  if (NOT ARG_SOURCES)
    file(GLOB_RECURSE ARG_SOURCES CONFIGURE_DEPENDS
      ${CMAKE_CURRENT_SOURCE_DIR}/${TEST_DIR_NAME}/*.hpp
      ${CMAKE_CURRENT_SOURCE_DIR}/${TEST_DIR_NAME}/*.cpp
    )
  endif()

  set(TEST_PKG_NAME "${ARG_PKG_NAME}${TEST_TARGET_SUFFIX}")

  build_pkg(
    PKG_NAME ${TEST_PKG_NAME}
    PKG_TYPE EXE
    NO_TEST_PKG ON
    NO_DOCS ON
    NO_EXAMPLES ON
    IDE_FOLDER ${ARG_IDE_FOLDER}
    SOURCES ${ARG_SOURCES}
    PUBLIC_LINK_LIBRARIES
      GTest::gtest_main
      ${ARG_PUBLIC_LINK_LIBRARIES}
    PRIVATE_LINK_LIBRARIES
      ${ARG_PKG_NAME}
      ${ARG_PRIVATE_LINK_LIBRARIES}
  )

  if (ARG_TEST_PREFIX)
    gtest_discover_tests(${TEST_PKG_NAME}
      TEST_PREFIX "${ARG_TEST_PREFIX}/"
      EXTRA_ARGS "--gtest_brief=1"
    )
  else()
    gtest_discover_tests(${TEST_PKG_NAME}
      EXTRA_ARGS "--gtest_brief=1"
    )
  endif()

  add_dependencies(${TEST_TARGET_NAME} ${TEST_PKG_NAME})

  if (WITH_COVERAGE)
    target_compile_options(${TEST_PKG_NAME} PRIVATE -fprofile-instr-generate -fcoverage-mapping)
    target_link_libraries(${TEST_PKG_NAME} PRIVATE -fprofile-instr-generate -fcoverage-mapping)

    add_custom_target(${TEST_PKG_NAME}${COVER_TARGET_SUFFIX}
      COMMAND $<TARGET_FILE:${TEST_PKG_NAME}> --gtest_output=xml:${CMAKE_CURRENT_BINARY_DIR}/default.xml
      DEPENDS ${TEST_PKG_NAME}
    )

    set_target_properties(${TEST_PKG_NAME}${COVER_TARGET_SUFFIX} PROPERTIES FOLDER ${ARG_IDE_FOLDER})

    # macOS has llvm-profdata in Xcode's toolchain, but it is not in the PATH
    # by default. We need to use xcrun to use it.
    set(LLVM_CMD_PREFIX "")
    if(${CMAKE_SYSTEM_NAME} STREQUAL "Darwin")
      set(LLVM_CMD_PREFIX xcrun)
    endif()

    # Generate coverage data from raw profile data
    add_custom_command(
      TARGET ${TEST_PKG_NAME}${COVER_TARGET_SUFFIX} POST_BUILD
      COMMAND ${LLVM_CMD_PREFIX} llvm-profdata merge -o ${TEST_PKG_NAME}.profdata default.profraw
      WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
      BYPRODUCTS ${CMAKE_CURRENT_BINARY_DIR}/${TEST_PKG_NAME}.profdata
    )

    # Generate LCOV coverage report
    if (WITH_LCOV_REPORT)
      add_custom_command(
        TARGET ${TEST_PKG_NAME}${COVER_TARGET_SUFFIX} POST_BUILD
        COMMAND ${LLVM_CMD_PREFIX} llvm-cov export -format=lcov ${TEST_PKG_NAME} -instr-profile=${TEST_PKG_NAME}.profdata > ${CMAKE_BINARY_DIR}/${COVERAGE_DIR_NAME}/${TEST_PKG_NAME}/lcov.info
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
        BYPRODUCTS ${CMAKE_BINARY_DIR}/${COVERAGE_DIR_NAME}/${TEST_PKG_NAME}/lcov.info
      )
    endif()

    # Generate HTML coverage report
    if (WITH_HTML_REPORT)
      add_custom_command(
        TARGET ${TEST_PKG_NAME}${COVER_TARGET_SUFFIX} POST_BUILD
        COMMAND ${LLVM_CMD_PREFIX} llvm-cov show -format html -o ${CMAKE_BINARY_DIR}/${COVERAGE_DIR_NAME}/${TEST_PKG_NAME}/html ${TEST_PKG_NAME} -instr-profile=${TEST_PKG_NAME}.profdata
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
        BYPRODUCTS ${CMAKE_BINARY_DIR}/${COVERAGE_DIR_NAME}/${TEST_PKG_NAME}/index.html
      )
    endif()

    add_dependencies(${COVER_TARGET_NAME} ${TEST_PKG_NAME}${COVER_TARGET_SUFFIX})
  endif()
endfunction()
