defmodule ProductiveWorkgroups.Workshops.Question do
  @moduledoc """
  Schema for workshop questions.

  Each question belongs to a template and defines:
  - The criterion being measured
  - The scale type (balance or maximal)
  - Discussion prompts for facilitation
  - Scoring guidance
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias ProductiveWorkgroups.Workshops.Template

  @scale_types ~w(balance maximal)

  schema "questions" do
    field :index, :integer
    field :title, :string
    field :criterion_number, :string
    field :criterion_name, :string
    field :explanation, :string
    field :scale_type, :string
    field :scale_min, :integer
    field :scale_max, :integer
    field :optimal_value, :integer
    field :discussion_prompts, {:array, :string}, default: []
    field :scoring_guidance, :string

    belongs_to :template, Template

    timestamps(type: :utc_datetime)
  end

  @required_fields ~w(index title criterion_number criterion_name explanation scale_type scale_min scale_max)a
  @optional_fields ~w(optimal_value discussion_prompts scoring_guidance)a

  @doc false
  def changeset(question, attrs) do
    question
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:scale_type, @scale_types)
    |> validate_number(:index, greater_than_or_equal_to: 0)
    |> validate_scale_range()
    |> unique_constraint(:index, name: :questions_template_id_index_index)
  end

  defp validate_scale_range(changeset) do
    scale_min = get_field(changeset, :scale_min)
    scale_max = get_field(changeset, :scale_max)

    if scale_min && scale_max && scale_min >= scale_max do
      add_error(changeset, :scale_max, "must be greater than scale_min")
    else
      changeset
    end
  end

  @doc """
  Returns the list of valid scale types.
  """
  def scale_types, do: @scale_types
end
