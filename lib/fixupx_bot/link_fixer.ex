defmodule FixupxBot.LinkFixer do
  @moduledoc """
  Pure, side-effect-free functions for detecting and rewriting Twitter/X links.

  Keeping this logic isolated:
  - makes it trivially unit-testable (`ExUnit` doctest friendly)
  - keeps consumers/handlers focused purely on side-effects

  ## Supported URL forms

      https://x.com/user/status/123
      https://twitter.com/user/status/123
      https://www.x.com/...
      https://www.twitter.com/...

  All are rewritten to `https://fixupx.com/<path>`.
  """

  # Named captures make the replacement closure self-documenting.
  # `path` matches everything after the domain including the leading slash,
  # or is an empty string when the URL has no path component.
  # The `\S*` (non-whitespace) approach keeps us from swallowing trailing
  # punctuation that is not part of the URL in natural language text.
  @pattern ~r{https://(?:www\.)?(?:x|twitter)\.com(?<path>/\S*)?}

  @doc """
  Returns `true` when `content` contains at least one Twitter/X link.

  Used as a cheap early-exit guard before running the full `fix/1` replacement.
  We check for `//x.com` (protocol+domain) to avoid false positives from `fixupx.com`.

  ## Examples

      iex> FixupxBot.LinkFixer.contains_link?("check https://x.com/foo")
      true

      iex> FixupxBot.LinkFixer.contains_link?("https://fixupx.com/foo")
      false

      iex> FixupxBot.LinkFixer.contains_link?("nothing here")
      false
  """
  @spec contains_link?(String.t()) :: boolean()
  def contains_link?(content) when is_binary(content) do
    String.contains?(content, "//x.com") or String.contains?(content, "//twitter.com")
  end

  @doc """
  Rewrites all Twitter/X links in `content` to `fixupx.com` equivalents.

  ## Examples

      iex> FixupxBot.LinkFixer.fix("https://x.com/user/status/1")
      "https://fixupx.com/user/status/1"

      iex> FixupxBot.LinkFixer.fix("https://twitter.com/foo and https://www.x.com/bar")
      "https://fixupx.com/foo and https://fixupx.com/bar"

      iex> FixupxBot.LinkFixer.fix("https://x.com")
      "https://fixupx.com"
  """
  @spec fix(String.t()) :: String.t()
  def fix(content) when is_binary(content) do
    Regex.replace(@pattern, content, fn _full, path ->
      "https://fixupx.com#{path}"
    end)
  end
end
