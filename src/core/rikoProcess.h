#pragma once

namespace riko::process {
    void parseCommands(int argc, char* argv[]);
    int initLibs();
    void parseConfig();
    int openScripts();
    int setupWindow();
    void cleanup();
}  // namespace riko::process
