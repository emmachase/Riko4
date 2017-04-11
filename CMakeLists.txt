cmake_minimum_required(VERSION 3.2)
project(riko4)

set(CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake/modules)

file(GLOB_RECURSE SOURCE_FILES Riko4/*.cpp Riko4/*.c)
add_executable(riko4 ${SOURCE_FILES}) 
add_definitions(-D__STDC_WANT_LIB_EXT1__=1)

if(UNIX)
	add_definitions(-DNO_STRERROR)
endif()

set(CMAKE_C_STANDARD 11)

find_package(SDL2 REQUIRED)

if(SDL2_FOUND)
	include_directories(${SDL2_INCLUDE_DIR})
	target_link_libraries(riko4 ${SDL2_LIBRARY})
endif()

find_package(LuaJIT REQUIRED)

if(LUAJIT_FOUND)
	include_directories(${LUAJIT_INCLUDE_DIR})
	target_link_libraries(riko4 ${LUAJIT_LIBRARIES})
endif()

include_directories(${CMAKE_SOURCE_DIR}/libs/include)
