cmake_minimum_required(VERSION 3.2)

project(riko4)

set(CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake/modules)

file(GLOB_RECURSE SOURCE_FILES src/*.cpp src/*.c src/*.h)
add_executable(riko4 ${SOURCE_FILES})

set_target_properties(riko4 PROPERTIES
        CXX_STANDARD 17
        CXX_STANDARD_REQUIRED ON)

find_package(PkgConfig REQUIRED)  
pkg_check_modules(LuaJIT REQUIRED IMPORTED_TARGET luajit)
target_link_libraries(riko4 PkgConfig::LuaJIT)

find_package(SDL2 CONFIG REQUIRED)
target_link_libraries(riko4
    $<TARGET_NAME_IF_EXISTS:SDL2::SDL2main>
    $<IF:$<TARGET_EXISTS:SDL2::SDL2>,SDL2::SDL2,SDL2::SDL2-static>
)

find_package(SDL_gpu CONFIG REQUIRED)

if (APPLE)
    target_link_libraries(riko4 SDL_gpu::SDL_gpu "-framework OpenGL")
else()
    target_link_libraries(riko4 SDL_gpu::SDL_gpu)
endif()

find_package(CURL REQUIRED)
target_link_libraries(riko4 CURL::libcurl)

find_package(unofficial-curlpp CONFIG REQUIRED)
target_link_libraries(riko4 unofficial::curlpp::curlpp)

include_directories(${CMAKE_SOURCE_DIR}/src)

if (WIN32)
    target_sources(riko4 PRIVATE ${CMAKE_SOURCE_DIR}/src/resources/icon.rc)
endif ()

if (APPLE)
    set(myApp_ICON ${CMAKE_CURRENT_SOURCE_DIR}/src/resources/icon.icns)
    set_source_files_properties(${myApp_ICON} PROPERTIES MACOSX_PACKAGE_LOCATION "Resources")

    set_target_properties(riko4 PROPERTIES
        MACOSX_BUNDLE TRUE
        MACOSX_BUNDLE_ICON_FILE icon.icns
        MACOSX_BUNDLE_BUNDLE_NAME "Riko4"
    )

    target_sources(riko4 PRIVATE ${myApp_ICON})

    set_target_properties(${PROJECT_NAME} PROPERTIES OUTPUT_NAME "Riko4")
endif ()

if (APPLE)
    install(TARGETS riko4 RUNTIME DESTINATION bin BUNDLE DESTINATION .)
else()
    install(TARGETS riko4 RUNTIME DESTINATION bin)
endif()
