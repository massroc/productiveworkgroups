defmodule ProductiveWorkgroups.Notes.Action do
  @moduledoc """
  Schema for action items.

  Actions capture commitments and next steps from the workshop.
  They are session-level items not tied to specific questions.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias ProductiveWorkgroups.Sessions.Session

  schema "actions" do
    field :description, :string
    field :owner_name, :string
    field :completed, :boolean, default: false

    belongs_to :session, Session

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(action, attrs) do
    action
    |> cast(attrs, [:description, :owner_name, :completed])
    |> validate_required([:description])
    |> validate_length(:description, min: 1, max: 1000)
    |> validate_length(:owner_name, max: 100)
  end

  @doc """
  Changeset for creating an action.
  """
  def create_changeset(action, session, attrs) do
    action
    |> changeset(attrs)
    |> put_assoc(:session, session)
  end

  @doc """
  Changeset for marking an action as completed or not completed.
  """
  def complete_changeset(action, completed) do
    action
    |> cast(%{completed: completed}, [:completed])
  end
end
