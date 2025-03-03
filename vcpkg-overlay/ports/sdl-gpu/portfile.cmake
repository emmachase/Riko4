vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO grimfang4/sdl-gpu
    REF v0.12.0
    SHA512 55b23661dec145c4f2c8d44ca6d0dabfc53803fef09668c69b6ea9af6693b1604e25107f1e42f1b75550365734f4c4c25c8a2dc9912fda4f18b1db459575ff80
    HEAD_REF master
    PATCHES
        add-exports.patch
)

# Configure CMake options based on library linkage
if(VCPKG_LIBRARY_LINKAGE STREQUAL "dynamic")
    set(BUILD_SHARED ON)
    set(BUILD_STATIC OFF)
    # Add DLL_EXPORT definition for proper exports
    set(ADDITIONAL_OPTIONS "-DCMAKE_C_FLAGS=-DDLL_EXPORT")
else()
    set(BUILD_SHARED OFF)
    set(BUILD_STATIC ON)
    set(ADDITIONAL_OPTIONS "")
endif()

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -DINSTALL_LIBRARY=ON
        -DBUILD_DEMOS=OFF
        -DBUILD_TESTS=OFF
        -DBUILD_VIDEO_TEST=OFF
        -DBUILD_DOCS=OFF
        -DBUILD_SHARED=${BUILD_SHARED}
        -DBUILD_STATIC=${BUILD_STATIC}
        ${ADDITIONAL_OPTIONS}
)

vcpkg_cmake_install()
vcpkg_copy_pdbs()

vcpkg_cmake_config_fixup(PACKAGE_NAME SDL_gpu)

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share")

file(INSTALL "${SOURCE_PATH}/LICENSE.txt" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright) 
configure_file("${CMAKE_CURRENT_LIST_DIR}/usage" "${CURRENT_PACKAGES_DIR}/share/${PORT}/usage" COPYONLY)
