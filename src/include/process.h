#pragma once

namespace riko::process {
    void parseCommands(int argc, char * argv[]);
    void initSDL();
    void parseConfig();
    int openScripts();
    int setupWindow();
    void cleanup();
}
