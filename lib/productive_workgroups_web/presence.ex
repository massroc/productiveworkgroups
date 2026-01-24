defmodule ProductiveWorkgroupsWeb.Presence do
  @moduledoc """
  Provides presence tracking for workshop sessions.

  Tracks which participants are currently connected to a session,
  enabling real-time updates when participants join, leave, or
  change their status.

  ## Usage

      # Track a participant
      ProductiveWorkgroupsWeb.Presence.track(
        self(),
        "session:\#{session_id}",
        participant_id,
        %{name: "Alice", status: "active"}
      )

      # List presences
      ProductiveWorkgroupsWeb.Presence.list("session:\#{session_id}")
  """

  use Phoenix.Presence,
    otp_app: :productive_workgroups,
    pubsub_server: ProductiveWorkgroups.PubSub

  @doc """
  Returns the topic for a session's presence tracking.
  """
  def session_topic(session_id) do
    "presence:session:#{session_id}"
  end

  @doc """
  Track a participant in a session.
  """
  def track_participant(pid, session_id, participant_id, meta) do
    track(pid, session_topic(session_id), participant_id, meta)
  end

  @doc """
  Update a participant's presence metadata.
  """
  def update_participant(pid, session_id, participant_id, meta) do
    update(pid, session_topic(session_id), participant_id, meta)
  end

  @doc """
  List all participants currently present in a session.
  """
  def list_participants(session_id) do
    list(session_topic(session_id))
  end
end
