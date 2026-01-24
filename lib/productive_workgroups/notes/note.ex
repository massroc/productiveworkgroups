defmodule ProductiveWorkgroups.Notes.Note do
  @moduledoc """
  Schema for discussion notes.

  Notes capture discussion points and observations during the workshop.
  They can be associated with a specific question (via question_index)
  or be general session-wide notes (when question_index is nil).
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias ProductiveWorkgroups.Sessions.Session

  schema "notes" do
    field :question_index, :integer
    field :content, :string
    field :author_name, :string

    belongs_to :session, Session

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(note, attrs) do
    note
    |> cast(attrs, [:question_index, :content, :author_name])
    |> validate_required([:content])
    |> validate_length(:content, min: 1, max: 2000)
    |> validate_length(:author_name, max: 100)
  end

  @doc """
  Changeset for creating a note.
  """
  def create_changeset(note, session, question_index, attrs) do
    note
    |> changeset(Map.put(attrs, :question_index, question_index))
    |> put_assoc(:session, session)
  end
end
