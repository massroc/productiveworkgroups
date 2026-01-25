defmodule ProductiveWorkgroups.Sessions.Participant do
  @moduledoc """
  Schema for workshop participants.

  A participant is a team member who has joined a workshop session.
  Participants are identified by a browser token for reconnection support.

  ## Statuses

  - `active` - Currently participating
  - `inactive` - Temporarily disconnected (may reconnect)
  - `dropped` - Left the session permanently
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias ProductiveWorkgroups.Sessions.Session

  @statuses ~w(active inactive dropped)

  schema "participants" do
    field :name, :string
    field :browser_token, Ecto.UUID
    field :status, :string, default: "active"
    field :is_ready, :boolean, default: false
    field :is_facilitator, :boolean, default: false
    field :joined_at, :utc_datetime
    field :last_seen_at, :utc_datetime

    belongs_to :session, Session

    timestamps(type: :utc_datetime)
  end

  @doc """
  Returns the list of valid participant statuses.
  """
  def statuses, do: @statuses

  @doc false
  def changeset(participant, attrs) do
    participant
    |> cast(attrs, [
      :name,
      :browser_token,
      :status,
      :is_ready,
      :is_facilitator,
      :joined_at,
      :last_seen_at
    ])
    |> validate_required([:name, :browser_token])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_inclusion(:status, @statuses)
    |> unique_constraint([:session_id, :browser_token])
  end

  @doc """
  Changeset for joining a session.
  """
  def join_changeset(participant, session, attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    participant
    |> changeset(Map.merge(attrs, %{joined_at: now, last_seen_at: now}))
    |> put_assoc(:session, session)
  end

  @doc """
  Changeset for updating participant status.
  """
  def status_changeset(participant, status) do
    participant
    |> cast(%{status: status, last_seen_at: DateTime.utc_now() |> DateTime.truncate(:second)}, [
      :status,
      :last_seen_at
    ])
    |> validate_inclusion(:status, @statuses)
  end

  @doc """
  Changeset for updating ready state.
  """
  def ready_changeset(participant, is_ready) do
    participant
    |> cast(%{is_ready: is_ready}, [:is_ready])
  end
end
