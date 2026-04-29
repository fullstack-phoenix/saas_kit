Code.require_file("support/test_mocks.ex", __DIR__)

Mimic.copy(Mix.Generator)
Mimic.copy(System)

ExUnit.start()
