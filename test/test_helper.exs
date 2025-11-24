Code.require_file("support/test_mocks.ex", __DIR__)

Mimic.copy(File)
Mimic.copy(Path)
Mimic.copy(Req)
Mimic.copy(Mix.Task)
Mimic.copy(Mix.Generator)
Mimic.copy(System)

ExUnit.start()
