local minos = {}

minos.I = {
    aox = 0.5, aoy = -0.5,
    offsets = { {-1.5, 0.5}, {-0.5, 0.5}, {0.5, 0.5}, {1.5, 0.5} },
    color = 12,
    name = "I"
}

minos.O = {
    aox = 0.5, aoy = 0.5,
    offsets = { {-0.5, -0.5}, {0.5, -0.5}, {-0.5, 0.5}, {0.5, 0.5} },
    color = 10,
    name = "O"
}

minos.T = {
    offsets = { {-1, 0}, {0, 0}, {1, 0}, {0, 1} },
    color = 14,
    name = "T"
}

minos.S = {
    offsets = { {-1, 0}, {0, 0}, {0, 1}, {1, 1} },
    color = 11,
    name = "S"
}

minos.Z = {
    offsets = { {-1, 1}, {0, 1}, {0, 0}, {1, 0} },
    color = 8,
    name = "Z"
}

minos.J = {
    offsets = { {-1, 0}, {0, 0}, {1, 0}, {-1, 1} },
    color = 13,
    name = "J"
}

minos.L = {
    offsets = { {-1, 0}, {0, 0}, {1, 0}, {1, 1} },
    color = 9,
    name = "L"
}

return minos