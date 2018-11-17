cmake_minimum_required(VERSION 3.2)
project(riko4)

if (APPLE)
    set(CMAKE_CXX_FLAGS ${CMAKE_CXX_FLAGS} "-pagezero_size 10000 -image_base 100000000")
endif ()

set($SDL2_gpu_PATH "${SDL2_gpu_PATH}" CACHE INTERNAL "SDL2_gpu" FORCE)

set(CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake/modules)

file(GLOB_RECURSE SOURCE_FILES src/*.cpp src/*.c src/*.h)
add_executable(riko4 ${SOURCE_FILES})

set_target_properties(riko4 PROPERTIES
        CXX_STANDARD 17
        CXX_STANDARD_REQUIRED ON)

find_package(SDL2 REQUIRED)

if (SDL2_FOUND)
    include_directories(${SDL2_INCLUDE_DIR})
    target_link_libraries(riko4 ${SDL2_LIBRARY})
endif ()

find_package(LuaJIT REQUIRED)

if (LUAJIT_FOUND)
    include_directories(${LUAJIT_INCLUDE_DIR})
    target_link_libraries(riko4 ${LUAJIT_LIBRARIES})
endif ()

find_package(SDL2_gpu REQUIRED)

if (SDL2_GPU_FOUND)
    include_directories(${SDL2_gpu_INCLUDE_DIR})
    target_link_libraries(riko4 ${SDL2_gpu_LIBRARY})
endif ()

find_package(CURL REQUIRED)

if (CURL_FOUND)
    include_directories(${CURL_INCLUDE_DIR})
    target_link_libraries(riko4 ${CURL_LIBRARY})
endif ()

find_package(CURLpp REQUIRED)

if (CURLPP_FOUND)
    include_directories(${CURLPP_INCLUDE_DIR})
    target_link_libraries(riko4 ${CURLPP_LIBRARY})
endif ()

include_directories(${CMAKE_SOURCE_DIR}/libs/include)
include_directories(${CMAKE_SOURCE_DIR}/src)

if (WIN32)
    target_link_libraries(riko4 ${CMAKE_SOURCE_DIR}/src/resources/icon.res)
endif ()

install(TARGETS riko4 RUNTIME DESTINATION bin)
