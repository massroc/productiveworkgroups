defmodule ProductiveWorkgroups.Repo.Migrations.AddCriterionNumberToQuestions do
  use Ecto.Migration

  def change do
    alter table(:questions) do
      add :criterion_number, :string
    end

    # Populate criterion_number for existing questions
    execute """
      UPDATE questions SET criterion_number = CASE index
        WHEN 0 THEN '1'
        WHEN 1 THEN '2a'
        WHEN 2 THEN '2b'
        WHEN 3 THEN '3'
        WHEN 4 THEN '4'
        WHEN 5 THEN '5a'
        WHEN 6 THEN '5b'
        WHEN 7 THEN '6'
      END
    """, ""

    # Update titles to remove numbering
    execute """
      UPDATE questions SET title = CASE index
        WHEN 0 THEN 'Elbow Room'
        WHEN 1 THEN 'Setting Goals'
        WHEN 2 THEN 'Getting Feedback'
        WHEN 3 THEN 'Variety'
        WHEN 4 THEN 'Mutual Support and Respect'
        WHEN 5 THEN 'Socially Useful'
        WHEN 6 THEN 'See Whole Product'
        WHEN 7 THEN 'Desirable Future'
      END
    """, ""
  end
end
