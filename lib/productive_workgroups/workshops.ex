defmodule ProductiveWorkgroups.Workshops do
  @moduledoc """
  The Workshops context.

  This context manages workshop templates and their questions.
  It provides the content and structure for running workshops.
  """

  import Ecto.Query, warn: false

  alias ProductiveWorkgroups.Repo
  alias ProductiveWorkgroups.Workshops.{Question, Template}

  ## Templates

  @doc """
  Returns the list of templates.

  ## Examples

      iex> list_templates()
      [%Template{}, ...]

  """
  def list_templates do
    Repo.all(Template)
  end

  @doc """
  Gets a single template.

  Raises `Ecto.NoResultsError` if the Template does not exist.

  ## Examples

      iex> get_template!(123)
      %Template{}

      iex> get_template!(456)
      ** (Ecto.NoResultsError)

  """
  def get_template!(id), do: Repo.get!(Template, id)

  @doc """
  Gets a single template by slug.

  Returns nil if the Template does not exist.

  ## Examples

      iex> get_template_by_slug("six-criteria")
      %Template{}

      iex> get_template_by_slug("non-existent")
      nil

  """
  def get_template_by_slug(slug) do
    Repo.get_by(Template, slug: slug)
  end

  @doc """
  Gets a template with its questions preloaded.

  ## Examples

      iex> get_template_with_questions(123)
      %Template{questions: [%Question{}, ...]}

  """
  def get_template_with_questions(id) do
    Template
    |> Repo.get!(id)
    |> Repo.preload(questions: from(q in Question, order_by: q.index))
  end

  @doc """
  Creates a template.

  ## Examples

      iex> create_template(%{field: value})
      {:ok, %Template{}}

      iex> create_template(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_template(attrs \\ %{}) do
    %Template{}
    |> Template.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a template.

  ## Examples

      iex> update_template(template, %{field: new_value})
      {:ok, %Template{}}

      iex> update_template(template, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_template(%Template{} = template, attrs) do
    template
    |> Template.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a template.

  ## Examples

      iex> delete_template(template)
      {:ok, %Template{}}

      iex> delete_template(template)
      {:error, %Ecto.Changeset{}}

  """
  def delete_template(%Template{} = template) do
    Repo.delete(template)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking template changes.

  ## Examples

      iex> change_template(template)
      %Ecto.Changeset{data: %Template{}}

  """
  def change_template(%Template{} = template, attrs \\ %{}) do
    Template.changeset(template, attrs)
  end

  ## Questions

  @doc """
  Returns the list of questions for a template, ordered by index.

  ## Examples

      iex> list_questions(template)
      [%Question{}, ...]

  """
  def list_questions(%Template{} = template) do
    Question
    |> where([q], q.template_id == ^template.id)
    |> order_by([q], q.index)
    |> Repo.all()
  end

  @doc """
  Gets a single question by template and index.

  Returns nil if the Question does not exist.

  ## Examples

      iex> get_question(template, 0)
      %Question{}

      iex> get_question(template, 99)
      nil

  """
  def get_question(%Template{} = template, index) do
    Repo.get_by(Question, template_id: template.id, index: index)
  end

  @doc """
  Gets the count of questions for a template.

  ## Examples

      iex> count_questions(template)
      8

  """
  def count_questions(%Template{} = template) do
    Question
    |> where([q], q.template_id == ^template.id)
    |> Repo.aggregate(:count)
  end

  @doc """
  Creates a question for a template.

  ## Examples

      iex> create_question(template, %{field: value})
      {:ok, %Question{}}

      iex> create_question(template, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_question(%Template{} = template, attrs \\ %{}) do
    %Question{}
    |> Question.changeset(attrs)
    |> Ecto.Changeset.put_assoc(:template, template)
    |> Repo.insert()
  end

  @doc """
  Updates a question.

  ## Examples

      iex> update_question(question, %{field: new_value})
      {:ok, %Question{}}

      iex> update_question(question, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_question(%Question{} = question, attrs) do
    question
    |> Question.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a question.

  ## Examples

      iex> delete_question(question)
      {:ok, %Question{}}

      iex> delete_question(question)
      {:error, %Ecto.Changeset{}}

  """
  def delete_question(%Question{} = question) do
    Repo.delete(question)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking question changes.

  ## Examples

      iex> change_question(question)
      %Ecto.Changeset{data: %Question{}}

  """
  def change_question(%Question{} = question, attrs \\ %{}) do
    Question.changeset(question, attrs)
  end
end
