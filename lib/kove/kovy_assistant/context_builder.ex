defmodule Kove.KovyAssistant.ContextBuilder do
  @moduledoc """
  Manages the conversation history that gets sent to the Groq API on every
  request, enforcing per-tier token budgets and message count limits.

  ## Why this matters

  Every API call sends the full `[system_prompt | history]` message list.
  Without trimming, a long conversation will eventually exceed the model's
  context window (128k tokens for llama-3.3-70b-versatile), causing a hard
  Groq API error that surfaces as a generic failure to the user.

  ## Tiers

  Two tiers enforce different limits based on whether the caller is an
  anonymous public visitor or an authenticated user:

  | Tier            | Max messages | History token budget |
  |-----------------|-------------|----------------------|
  | `:public`       | 20          | 24 000               |
  | `:authenticated`| 50          | 72 000               |

  The **history token budget** is for the conversation history only — the
  system prompt consumes its own portion of the model's context window on
  top of this budget.

  Token estimation uses a conservative `ceil(byte_size(text) / 3)` formula
  (English LLM tokens average ~3–4 bytes each). This slightly over-counts,
  which is intentional — better to trim one message too many than to blow
  the context limit.
  """

  # Per-tier configuration: {max_messages, history_token_budget}
  @tiers %{
    public: %{max_messages: 20, token_budget: 24_000},
    authenticated: %{max_messages: 50, token_budget: 72_000}
  }

  @doc """
  Trims `history` to fit within the limits of `tier`.

  The most recent messages are preferred — we walk the history in reverse,
  accumulating messages until we hit the message cap or token budget, then
  reverse the result back to chronological order.

  Always preserves whole message pairs (user + assistant) where possible to
  avoid presenting the LLM with a dangling assistant turn at the start of
  the trimmed window.

  Returns the trimmed history list.
  """
  @spec trim_history(list(map()), :public | :authenticated) :: list(map())
  def trim_history(history, tier \\ :public) when is_list(history) do
    %{max_messages: max_msgs, token_budget: budget} = tier_config(tier)

    history
    |> Enum.reverse()
    |> take_within_budget(max_msgs, budget, [])
    |> drop_leading_assistant()
  end

  @doc """
  Returns the tier configuration map for the given tier atom.
  Falls back to `:public` config for any unknown tier.
  """
  @spec tier_config(:public | :authenticated) :: %{
          max_messages: pos_integer(),
          token_budget: pos_integer()
        }
  def tier_config(tier) do
    Map.get(@tiers, tier, @tiers.public)
  end

  # ── Private helpers ──────────────────────────────────────────────────

  # Walk reversed history, taking messages until we hit the cap or budget.
  defp take_within_budget([], _max, _budget, acc), do: acc

  defp take_within_budget(_rest, 0, _budget, acc), do: acc

  defp take_within_budget([msg | rest], max, budget, acc) do
    cost = estimate_tokens(msg.content)

    if cost > budget do
      # This single message alone blows the remaining budget — stop here.
      acc
    else
      take_within_budget(rest, max - 1, budget - cost, [msg | acc])
    end
  end

  # If trimming cut off the beginning of the conversation mid-exchange, the
  # first remaining message might be an :assistant turn (its user turn was
  # dropped). Drop it so the history always starts with a user message.
  defp drop_leading_assistant([%{role: :assistant} | rest]), do: rest
  defp drop_leading_assistant(history), do: history

  # Conservative token estimate: ceil(byte_size / 3).
  # Intentionally over-counts slightly to stay safely under context limits.
  defp estimate_tokens(text) when is_binary(text) do
    ceil(byte_size(text) / 3)
  end

  defp estimate_tokens(_), do: 0
end
