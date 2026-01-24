defmodule ProductiveWorkgroups.Notes do
  @moduledoc """
  The Notes context.

  This context manages discussion notes and action items
  captured during workshop sessions.
  """

  import Ecto.Query, warn: false
  alias ProductiveWorkgroups.Repo
  alias ProductiveWorkgroups.Notes.{Note, Action}
  alias ProductiveWorkgroups.Sessions.Session

  ## Notes

  @doc """
  Creates a note for a session.

  Pass `question_index: nil` for general session notes,
  or a specific index for question-related notes.
  """
  def create_note(%Session{} = session, question_index, attrs) do
    %Note{}
    |> Note.create_changeset(session, question_index, attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a note.
  """
  def update_note(%Note{} = note, attrs) do
    note
    |> Note.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a note.
  """
  def delete_note(%Note{} = note) do
    Repo.delete(note)
  end

  @doc """
  Lists notes for a specific question.
  """
  def list_notes_for_question(%Session{} = session, question_index) do
    Note
    |> where([n], n.session_id == ^session.id and n.question_index == ^question_index)
    |> order_by([n], n.inserted_at)
    |> Repo.all()
  end

  @doc """
  Lists general (non-question-specific) notes for a session.
  """
  def list_general_notes(%Session{} = session) do
    Note
    |> where([n], n.session_id == ^session.id and is_nil(n.question_index))
    |> order_by([n], n.inserted_at)
    |> Repo.all()
  end

  @doc """
  Lists all notes for a session.
  """
  def list_all_notes(%Session{} = session) do
    Note
    |> where([n], n.session_id == ^session.id)
    |> order_by([n], [n.question_index, n.inserted_at])
    |> Repo.all()
  end

  @doc """
  Counts the total number of notes in a session.
  """
  def count_notes(%Session{} = session) do
    Note
    |> where([n], n.session_id == ^session.id)
    |> Repo.aggregate(:count)
  end

  ## Actions

  @doc """
  Creates an action for a session.

  Pass `question_index: nil` for general session actions,
  or a specific index for question-related actions.
  """
  def create_action(%Session{} = session, question_index, attrs) do
    %Action{}
    |> Action.create_changeset(session, question_index, attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an action.
  """
  def update_action(%Action{} = action, attrs) do
    action
    |> Action.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Marks an action as completed.
  """
  def complete_action(%Action{} = action) do
    action
    |> Action.complete_changeset(true)
    |> Repo.update()
  end

  @doc """
  Marks an action as not completed.
  """
  def uncomplete_action(%Action{} = action) do
    action
    |> Action.complete_changeset(false)
    |> Repo.update()
  end

  @doc """
  Deletes an action.
  """
  def delete_action(%Action{} = action) do
    Repo.delete(action)
  end

  @doc """
  Lists actions for a specific question.
  """
  def list_actions_for_question(%Session{} = session, question_index) do
    Action
    |> where([a], a.session_id == ^session.id and a.question_index == ^question_index)
    |> order_by([a], a.inserted_at)
    |> Repo.all()
  end

  @doc """
  Lists general (non-question-specific) actions for a session.
  """
  def list_general_actions(%Session{} = session) do
    Action
    |> where([a], a.session_id == ^session.id and is_nil(a.question_index))
    |> order_by([a], a.inserted_at)
    |> Repo.all()
  end

  @doc """
  Lists all actions for a session.
  """
  def list_all_actions(%Session{} = session) do
    Action
    |> where([a], a.session_id == ^session.id)
    |> order_by([a], [a.question_index, a.inserted_at])
    |> Repo.all()
  end

  @doc """
  Counts the total number of actions in a session.
  """
  def count_actions(%Session{} = session) do
    Action
    |> where([a], a.session_id == ^session.id)
    |> Repo.aggregate(:count)
  end

  @doc """
  Counts the number of completed actions in a session.
  """
  def count_completed_actions(%Session{} = session) do
    Action
    |> where([a], a.session_id == ^session.id and a.completed == true)
    |> Repo.aggregate(:count)
  end
end
