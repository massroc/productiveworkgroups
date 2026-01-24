defmodule ProductiveWorkgroups.Notes.Action do
  @moduledoc """
  Schema for action items.

  Actions capture commitments and next steps from the workshop.
  They can be associated with a specific question (via question_index)
  or be general session-wide actions (when question_index is nil).
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias ProductiveWorkgroups.Sessions.Session

  schema "actions" do
    field :question_index, :integer
    field :description, :string
    field :owner_name, :string
    field :completed, :boolean, default: false

    belongs_to :session, Session

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(action, attrs) do
    action
    |> cast(attrs, [:question_index, :description, :owner_name, :completed])
    |> validate_required([:description])
    |> validate_length(:description, min: 1, max: 1000)
    |> validate_length(:owner_name, max: 100)
  end

  @doc """
  Changeset for creating an action.
  """
  def create_changeset(action, session, question_index, attrs) do
    action
    |> changeset(Map.put(attrs, :question_index, question_index))
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
