defmodule ProductiveWorkgroups.Workshops.Template do
  @moduledoc """
  Schema for workshop templates.

  A template defines a type of workshop, including its name, description,
  and default duration. The Six Criteria workshop is the primary template.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias ProductiveWorkgroups.Workshops.Question

  schema "templates" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :version, :string, default: "1.0.0"
    field :default_duration_minutes, :integer, default: 210

    has_many :questions, Question

    timestamps(type: :utc_datetime)
  end

  @required_fields ~w(name slug version default_duration_minutes)a
  @optional_fields ~w(description)a

  @doc false
  def changeset(template, attrs) do
    template
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:name, min: 1, max: 255)
    |> validate_length(:slug, min: 1, max: 100)
    |> validate_format(:slug, ~r/^[a-z0-9-]+$/, message: "must only contain lowercase letters, numbers, and hyphens")
    |> validate_number(:default_duration_minutes, greater_than: 0)
    |> unique_constraint(:slug)
  end
end
