with import <nixpkgs> {};

stdenv.mkDerivation {
  name = "riko4";
  version = "0.1.1"; # put something sensible here
  src = ./.;

  buildInputs = [ SDL2 luajit
                  cmake ];

  cmakeFlags = [ "-DSDL2_LIBRARIES=\"${SDL2}/lib/\""
                 "-DSDL2_INCLUDE_DIR=\"${SDL2}/include\""
                 "-DLUAJIT_DIR=\"${luajit}\"/" ];

  installPhase = ''
  install -Dm0755 riko4 $out/bin/riko4
  '';
  meta = with stdenv.lib; {
    description = "Fantasy console for pixel art game development";
    license = licenses.mit;
    maintainers = [];
  };
}
