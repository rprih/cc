return {
    {
        id = "fission-reactor-controller",
        name = "Fission Reactor Controller",
        files = {
            "common/communication.lua",
            "machines/fission-reactor/controller.lua",
        },
        startup = "machines/fission-reactor/controller.lua",
    },
    {
        id = "fission-reactor-turbine-controller",
        name = "Fission Reactor Turbine Controller",
        files = {
            "common/terminal.lua",
            "machines/fission-reactor-turbine/controller.lua",
        },
        startup = "machines/fission-reactor-turbine/controller.lua",
    },
    {
        id = "matrix-telemetry-transmitter",
        name = "Matrix Telemetry Transmitter",
        files = {
            "common/communication.lua",
            "machines/main-matrix/battery-telemetry-transmitter.lua",
        },
        startup = "machines/main-matrix/battery-telemetry-transmitter.lua",
    }
}
