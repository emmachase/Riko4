# Riko4 [![Build Status](https://travis-ci.org/emmachase/Riko4.svg?branch=master)](https://travis-ci.org/emmachase/Riko4)

A fantasy computer / game engine

Build Instructions with vcpkg:

```
# First, set up vcpkg if you haven't already
git clone https://github.com/Microsoft/vcpkg.git
cd vcpkg
./bootstrap-vcpkg.sh  # On Linux/macOS
# OR
.\bootstrap-vcpkg.bat  # On Windows

# Clone Riko4 and build
git clone https://github.com/emmachase/riko4
cd riko4
mkdir build
cp -r scripts build
cd build
cmake .. -DCMAKE_TOOLCHAIN_FILE=[path to vcpkg]/scripts/buildsystems/vcpkg.cmake
cmake --build .
```

Alternatively, create a CMakeUserPresets.json:

```jsonc
{
    "version": 2,
    "configurePresets": [
        {
            "name": "default",
            "inherits": "vcpkg",
            "generator": "Unix Makefiles", // Or your preferred Generator
            "environment": {
                "VCPKG_ROOT": "C:/code/vcpkg"
            }
        }
    ]
}
```

Then:
```
cmake .. --preset default
cmake --build .
```

Screenshots:
![Hello World](https://its-em.ma/and-her-thirsty-stitch.jfif)
![Shell](https://its-em.ma/and-her-internal-shoe.jfif)
![Code Editor](https://its-em.ma/and-her-whispering-father.jfif)
![Image/Spritesheet Editor](https://its-em.ma/and-her-spiffy-hen.jfif)
![Isola Game](https://its-em.ma/and-her-naive-sleep.jfif)
![Minesweeper](https://its-em.ma/and-her-wacky-belief.jfif)
