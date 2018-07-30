# Riko4 [![Build Status](https://travis-ci.org/incinirate/Riko4.svg?branch=master)](https://travis-ci.org/incinirate/Riko4)

A fantasy computer / game engine

Required Dependencies:

```
luajit - Ubuntu: libluajit-5.1-dev, Arch: luajit
sdl2 - Ubuntu: libsdl2-dev, Arch: sdl2

sdl_gpu - No avaliable binaries from package repositories afaik,
 either build from https://github.com/grimfang4/sdl-gpu or grab a
 released copy from https://github.com/grimfang4/sdl-gpu/releases
 
curlpp - Ubuntu: libcurlpp-dev, Arch: aur/libcurlpp
```

Build Instructions:

```
git clone https://github.com/incinirate/riko4
cd riko4
mkdir build
cp -r scripts build
cp -r data build
cd build
cmake ..
make
```

Screenshots:
![Hello World](https://i.would.download/a-gate.png)
![Shell](https://i.would.download/a-vacation.png)
![Code Editor](https://i.would.download/a-frame.png)
![Image/Spritesheet Editor](https://i.would.download/a-hot.png)
![Isola Game](https://i.would.download/a-wall.png)
![Minesweeper](https://i.would.download/a-railway.png)
