CC = g++

LINK = g++

COMPILER_FLAGS = -lstdc++ -static-libgcc -static-libstdc++
LINKER_FLAGS = -lstdc++ -static-libgcc -static-libstdc++

INCLUDE_PATHS = -Ilibs/include -IRiko4
LIBRARY_PATHS = -Llibs/SDL2 -Llibs/LuaJIT

LIBRARIES = -lSDL2main -lSDL2 -llua51

.PHONY : all
all : app
 
# Link the object files into a binary
app : riko.o AudioLib.o GPULib.o ImageLib.o
	$(LINK) $(LINKER_FLAGS) $(INCLUDE_PATHS) $(LIBRARY_PATHS) Riko4/riko.o Riko4/AudioLib.o Riko4/GPULib.o Riko4/ImageLib.o $(LIBRARIES) -o riko4
 
# Compile the source files into object files
riko.o : Riko4/riko.cpp
	$(CC) $(COMPILER_FLAGS) $(INCLUDE_PATHS) $(LIBRARY_PATHS) Riko4/riko.cpp $(LIBRARIES) -c -o Riko4/riko.o

AudioLib.o : Riko4/AudioLib.cpp
	$(CC) $(COMPILER_FLAGS) $(INCLUDE_PATHS) $(LIBRARY_PATHS) Riko4/AudioLib.cpp $(LIBRARIES) -c -o Riko4/AudioLib.o

GPULib.o : Riko4/GPULib.cpp
	$(CC) $(COMPILER_FLAGS) $(INCLUDE_PATHS) $(LIBRARY_PATHS) Riko4/GPULib.cpp $(LIBRARIES) -c -o Riko4/GPULib.o

ImageLib.o : Riko4/ImageLib.cpp
	$(CC) $(COMPILER_FLAGS) $(INCLUDE_PATHS) $(LIBRARY_PATHS) Riko4/ImageLib.cpp $(LIBRARIES) -c -o Riko4/ImageLib.o

# Clean target
.PHONY : clean
clean :
	rm Riko4/riko.o Riko4/AudioLib.o Riko4/GPULib.o Riko4/ImageLib.o