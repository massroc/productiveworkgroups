defmodule ProductiveWorkgroups.Sessions do
  @moduledoc """
  The Sessions context.

  This context manages workshop sessions and their participants.
  It handles session lifecycle, participant management, and state transitions.
  """

  import Ecto.Query, warn: false

  alias ProductiveWorkgroups.Repo
  alias ProductiveWorkgroups.Sessions.{Participant, Session}
  alias ProductiveWorkgroups.Workshops.Template

  @pubsub ProductiveWorkgroups.PubSub

  ## PubSub Helpers

  @doc """
  Returns the PubSub topic for a session.
  """
  def session_topic(%Session{id: id}), do: "session:#{id}"
  def session_topic(session_id) when is_binary(session_id), do: "session:#{session_id}"

  @doc """
  Subscribes to session updates.
  """
  def subscribe(%Session{} = session) do
    Phoenix.PubSub.subscribe(@pubsub, session_topic(session))
  end

  defp broadcast(%Session{} = session, event) do
    Phoenix.PubSub.broadcast(@pubsub, session_topic(session), event)
    :ok
  end

  ## Session Code Generation

  @code_chars ~c"ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
  @code_length 6

  @doc """
  Generates a unique session code.

  Codes are alphanumeric, uppercase, and avoid ambiguous characters
  (0/O, 1/I/L) for easier reading and sharing.
  """
  def generate_code do
    for _ <- 1..@code_length, into: "" do
      <<Enum.random(@code_chars)>>
    end
  end

  ## Sessions

  @doc """
  Creates a new session for the given template.

  ## Options

  - `:planned_duration_minutes` - Optional planned duration
  - `:settings` - Optional map of session settings
  """
  def create_session(%Template{} = template, attrs \\ %{}) do
    code = generate_unique_code()

    # Normalize attrs to string keys for consistency with form params
    normalized_attrs =
      attrs
      |> Enum.map(fn
        {k, v} when is_atom(k) -> {Atom.to_string(k), v}
        {k, v} -> {k, v}
      end)
      |> Map.new()
      |> Map.put("code", code)

    %Session{}
    |> Session.create_changeset(template, normalized_attrs)
    |> Repo.insert()
  end

  defp generate_unique_code do
    code = generate_code()

    if get_session_by_code(code) do
      generate_unique_code()
    else
      code
    end
  end

  @doc """
  Gets a single session.

  Raises `Ecto.NoResultsError` if the Session does not exist.
  """
  def get_session!(id), do: Repo.get!(Session, id)

  @doc """
  Gets a session by its code.

  The lookup is case-insensitive.
  Returns nil if no session is found.
  """
  def get_session_by_code(code) when is_binary(code) do
    normalized_code = String.upcase(code)
    Repo.get_by(Session, code: normalized_code)
  end

  @doc """
  Gets a session with participants preloaded.
  """
  def get_session_with_participants(id) do
    Session
    |> Repo.get!(id)
    |> Repo.preload(:participants)
  end

  @doc """
  Gets a session with template and participants preloaded.
  """
  def get_session_with_all(id) do
    Session
    |> Repo.get!(id)
    |> Repo.preload([:template, :participants])
  end

  ## Session State Transitions

  @doc """
  Starts a session, transitioning from lobby to intro.
  """
  def start_session(%Session{state: "lobby"} = session) do
    result =
      session
      |> Session.transition_changeset("intro", %{
        started_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })
      |> Repo.update()

    case result do
      {:ok, updated_session} ->
        broadcast(updated_session, {:session_started, updated_session})
        {:ok, updated_session}

      error ->
        error
    end
  end

  @doc """
  Advances from intro to scoring phase.
  """
  def advance_to_scoring(%Session{state: "intro"} = session) do
    result =
      session
      |> Session.transition_changeset("scoring", %{current_question_index: 0})
      |> Repo.update()

    broadcast_session_update(result)
  end

  @doc """
  Advances to the next question within the scoring phase.
  """
  def advance_question(%Session{state: "scoring"} = session) do
    result =
      session
      |> Session.transition_changeset("scoring", %{
        current_question_index: session.current_question_index + 1
      })
      |> Repo.update()

    broadcast_session_update(result)
  end

  @doc """
  Advances from scoring to summary phase.
  """
  def advance_to_summary(%Session{state: "scoring"} = session) do
    result =
      session
      |> Session.transition_changeset("summary")
      |> Repo.update()

    broadcast_session_update(result)
  end

  @doc """
  Advances from summary to actions phase.
  """
  def advance_to_actions(%Session{state: "summary"} = session) do
    result =
      session
      |> Session.transition_changeset("actions")
      |> Repo.update()

    broadcast_session_update(result)
  end

  @doc """
  Completes the session.
  """
  def complete_session(%Session{state: "actions"} = session) do
    result =
      session
      |> Session.transition_changeset("completed", %{
        completed_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })
      |> Repo.update()

    broadcast_session_update(result)
  end

  ## Backward Navigation

  @doc """
  Goes back to the previous question within the scoring phase.

  Returns `{:error, :at_first_question}` if already at question 0.
  """
  def go_back_question(%Session{state: "scoring", current_question_index: 0}) do
    {:error, :at_first_question}
  end

  def go_back_question(%Session{state: "scoring"} = session) do
    result =
      session
      |> Session.transition_changeset("scoring", %{
        current_question_index: session.current_question_index - 1
      })
      |> Repo.update()

    broadcast_session_update(result)
  end

  @doc """
  Goes back from scoring (at question 0) to intro.
  """
  def go_back_to_intro(%Session{state: "scoring", current_question_index: 0} = session) do
    result =
      session
      |> Session.transition_changeset("intro", %{current_question_index: 0})
      |> Repo.update()

    broadcast_session_update(result)
  end

  @doc """
  Goes back from summary to the last scoring question.
  """
  def go_back_to_scoring(%Session{state: "summary"} = session, last_question_index) do
    result =
      session
      |> Session.transition_changeset("scoring", %{current_question_index: last_question_index})
      |> Repo.update()

    broadcast_session_update(result)
  end

  @doc """
  Goes back from actions to summary.
  """
  def go_back_to_summary(%Session{state: "actions"} = session) do
    result =
      session
      |> Session.transition_changeset("summary")
      |> Repo.update()

    broadcast_session_update(result)
  end

  defp broadcast_session_update({:ok, session}) do
    broadcast(session, {:session_updated, session})
    {:ok, session}
  end

  defp broadcast_session_update(error), do: error

  @doc """
  Updates the last_activity_at timestamp for the session.
  """
  def touch_session(%Session{} = session) do
    session
    |> Ecto.Changeset.change(last_activity_at: DateTime.utc_now() |> DateTime.truncate(:second))
    |> Repo.update()
  end

  ## Participants

  @doc """
  Joins a participant to a session.

  If a participant with the same browser_token already exists,
  their name is updated and they are returned.

  ## Options

  - `:is_facilitator` - Set to true if this participant is the facilitator
  """
  def join_session(%Session{} = session, name, browser_token, opts \\ []) do
    is_facilitator = Keyword.get(opts, :is_facilitator, false)
    is_observer = Keyword.get(opts, :is_observer, false)

    case get_participant(session, browser_token) do
      nil ->
        result =
          %Participant{}
          |> Participant.join_changeset(session, %{
            name: name,
            browser_token: browser_token,
            is_facilitator: is_facilitator,
            is_observer: is_observer
          })
          |> Repo.insert()

        case result do
          {:ok, participant} ->
            broadcast(session, {:participant_joined, participant})
            {:ok, participant}

          error ->
            error
        end

      existing ->
        existing
        |> Participant.changeset(%{
          name: name,
          last_seen_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })
        |> Repo.update()
    end
  end

  @doc """
  Gets the facilitator of a session.
  """
  def get_facilitator(%Session{} = session) do
    Participant
    |> where([p], p.session_id == ^session.id and p.is_facilitator == true)
    |> Repo.one()
  end

  @doc """
  Gets a participant by their browser token.
  """
  def get_participant(%Session{} = session, browser_token) do
    Repo.get_by(Participant, session_id: session.id, browser_token: browser_token)
  end

  @doc """
  Gets a participant by their browser token.

  Alias for `get_participant/2`.
  """
  def get_participant_by_token(%Session{} = session, browser_token) do
    get_participant(session, browser_token)
  end

  @doc """
  Lists all participants in a session.
  """
  def list_participants(%Session{} = session) do
    Participant
    |> where([p], p.session_id == ^session.id)
    |> order_by([p], p.joined_at)
    |> Repo.all()
  end

  @doc """
  Lists only active participants in a session.
  """
  def list_active_participants(%Session{} = session) do
    Participant
    |> where([p], p.session_id == ^session.id and p.status == "active")
    |> order_by([p], p.joined_at)
    |> Repo.all()
  end

  @doc """
  Counts participants in a session.
  """
  def count_participants(%Session{} = session) do
    Participant
    |> where([p], p.session_id == ^session.id)
    |> Repo.aggregate(:count)
  end

  @doc """
  Updates a participant's status.
  """
  def update_participant_status(%Participant{} = participant, status) do
    result =
      participant
      |> Participant.status_changeset(status)
      |> Repo.update()

    case result do
      {:ok, updated} ->
        session = Repo.get!(Session, participant.session_id)

        if status == "dropped" do
          broadcast(session, {:participant_left, updated.id})
        else
          broadcast(session, {:participant_updated, updated})
        end

        {:ok, updated}

      error ->
        error
    end
  end

  @doc """
  Sets a participant's ready state.
  """
  def set_participant_ready(%Participant{} = participant, is_ready) do
    result =
      participant
      |> Participant.ready_changeset(is_ready)
      |> Repo.update()

    case result do
      {:ok, updated} ->
        session = Repo.get!(Session, participant.session_id)
        broadcast(session, {:participant_ready, updated})
        {:ok, updated}

      error ->
        error
    end
  end

  @doc """
  Resets all participants' ready state to false.
  """
  def reset_all_ready(%Session{} = session) do
    Participant
    |> where([p], p.session_id == ^session.id)
    |> Repo.update_all(set: [is_ready: false])

    :ok
  end

  @doc """
  Checks if all active participants are ready.
  """
  def all_participants_ready?(%Session{} = session) do
    active_count =
      Participant
      |> where([p], p.session_id == ^session.id and p.status == "active")
      |> Repo.aggregate(:count)

    ready_count =
      Participant
      |> where([p], p.session_id == ^session.id and p.status == "active" and p.is_ready == true)
      |> Repo.aggregate(:count)

    active_count > 0 and active_count == ready_count
  end
end
