ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Kove.Repo, :manual)

Mox.defmock(Kove.KovyAssistant.GroqMock, for: Kove.KovyAssistant.GroqBehaviour)
