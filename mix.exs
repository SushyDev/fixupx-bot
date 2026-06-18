defmodule FixupxBot.MixProject do
  use Mix.Project

  def project do
    [
      app: :fixupx_bot,
      version: "0.1.0",
      # Pin to the version running in this repo's dev environment.
      # ~> 1.19 allows any 1.x >= 1.19; tighten to "== 1.19.5" if you need
      # a hard pin in production.
      elixir: "~> 1.19",
      # Emit warnings for any deprecated Elixir features caught at compile time.
      elixirc_options: [warnings_as_errors: false],
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      # Dialyzer / ExDoc friendly
      name: "FixupX Bot",
      description: "Discord bot that rewrites Twitter/X links to fixupx.com"
    ]
  end

  # The application callback starts our supervision tree.
  # nostrum's own OTP application (and its supervisor) is started automatically
  # as a transitive dependency — we do not list it here.
  def application do
    [
      extra_applications: [:logger],
      mod: {FixupxBot.Application, []}
    ]
  end

  defp deps do
    [
      # Discord gateway + REST library — latest stable as of 2025.
      {:nostrum, "~> 0.10"},

      # gun is nostrum's default HTTP/WebSocket adapter.
      # Must be declared explicitly so Mix can resolve the version correctly.
      # override: true avoids version conflicts when multiple deps pull gun.
      {:gun, "~> 2.0", override: true},

      # OTP 27+ ships stdlib :json, but nostrum still declares jason as its
      # JSON dependency for OTP 24/25/26 compatibility.  On OTP 28 jason is
      # still the fastest option and carries no overhead.
      {:jason, "~> 1.4"}
    ]
  end
end
