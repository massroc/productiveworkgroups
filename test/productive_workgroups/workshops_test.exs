defmodule ProductiveWorkgroups.WorkshopsTest do
  use ProductiveWorkgroups.DataCase, async: true

  alias ProductiveWorkgroups.Workshops
  alias ProductiveWorkgroups.Workshops.{Question, Template}

  describe "templates" do
    @valid_attrs %{
      name: "Six Criteria Workshop",
      slug: "six-criteria",
      description: "Explore the six criteria of productive work",
      version: "1.0.0",
      default_duration_minutes: 210
    }

    test "create_template/1 with valid data creates a template" do
      assert {:ok, %Template{} = template} = Workshops.create_template(@valid_attrs)
      assert template.name == "Six Criteria Workshop"
      assert template.slug == "six-criteria"
      assert template.version == "1.0.0"
      assert template.default_duration_minutes == 210
    end

    test "create_template/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Workshops.create_template(%{})
    end

    test "create_template/1 requires unique slug" do
      {:ok, _template} = Workshops.create_template(@valid_attrs)

      assert {:error, changeset} =
               Workshops.create_template(%{@valid_attrs | name: "Another Workshop"})

      assert "has already been taken" in errors_on(changeset).slug
    end

    test "get_template!/1 returns the template with given id" do
      {:ok, template} = Workshops.create_template(@valid_attrs)
      assert Workshops.get_template!(template.id).id == template.id
    end

    test "get_template_by_slug/1 returns the template with given slug" do
      {:ok, template} = Workshops.create_template(@valid_attrs)
      assert Workshops.get_template_by_slug("six-criteria").id == template.id
    end

    test "get_template_by_slug/1 returns nil for non-existent slug" do
      assert Workshops.get_template_by_slug("non-existent") == nil
    end

    test "list_templates/0 returns all templates" do
      {:ok, template} = Workshops.create_template(@valid_attrs)
      assert Workshops.list_templates() == [template]
    end
  end

  describe "questions" do
    setup do
      {:ok, template} =
        Workshops.create_template(%{
          name: "Test Workshop",
          slug: "test-workshop",
          version: "1.0.0",
          default_duration_minutes: 60
        })

      %{template: template}
    end

    @valid_question_attrs %{
      index: 0,
      title: "Elbow Room",
      criterion_name: "Autonomy",
      explanation: "The degree of autonomy you have in how you do your work.",
      scale_type: "balance",
      scale_min: -5,
      scale_max: 5,
      optimal_value: 0,
      discussion_prompts: [
        "What aspects give you the most freedom?",
        "Where do you feel constrained?"
      ],
      scoring_guidance: "Consider your day-to-day work decisions."
    }

    test "create_question/2 with valid data creates a question", %{template: template} do
      assert {:ok, %Question{} = question} =
               Workshops.create_question(template, @valid_question_attrs)

      assert question.title == "Elbow Room"
      assert question.scale_type == "balance"
      assert question.scale_min == -5
      assert question.scale_max == 5
      assert question.optimal_value == 0
      assert question.template_id == template.id
    end

    test "create_question/2 for maximal scale type", %{template: template} do
      attrs = %{
        index: 4,
        title: "Mutual Support",
        criterion_name: "Support",
        explanation: "The level of support and respect in your team.",
        scale_type: "maximal",
        scale_min: 0,
        scale_max: 10,
        optimal_value: nil,
        discussion_prompts: ["How do team members help each other?"],
        scoring_guidance: "Think about collaboration."
      }

      assert {:ok, %Question{} = question} = Workshops.create_question(template, attrs)
      assert question.scale_type == "maximal"
      assert question.optimal_value == nil
    end

    test "create_question/2 enforces unique index per template", %{template: template} do
      {:ok, _} = Workshops.create_question(template, @valid_question_attrs)

      assert {:error, changeset} =
               Workshops.create_question(template, %{@valid_question_attrs | title: "Different"})

      assert "has already been taken" in errors_on(changeset).index
    end

    test "create_question/2 requires valid scale_type", %{template: template} do
      attrs = %{@valid_question_attrs | scale_type: "invalid"}
      assert {:error, changeset} = Workshops.create_question(template, attrs)
      assert "is invalid" in errors_on(changeset).scale_type
    end

    test "list_questions/1 returns questions for a template in order", %{template: template} do
      {:ok, _q2} =
        Workshops.create_question(template, %{@valid_question_attrs | index: 1, title: "Q2"})

      {:ok, _q1} =
        Workshops.create_question(template, %{@valid_question_attrs | index: 0, title: "Q1"})

      {:ok, _q3} =
        Workshops.create_question(template, %{@valid_question_attrs | index: 2, title: "Q3"})

      questions = Workshops.list_questions(template)
      assert length(questions) == 3
      assert Enum.map(questions, & &1.index) == [0, 1, 2]
    end

    test "get_question/2 returns the question at given index", %{template: template} do
      {:ok, question} = Workshops.create_question(template, @valid_question_attrs)
      assert Workshops.get_question(template, 0).id == question.id
    end

    test "get_question/2 returns nil for non-existent index", %{template: template} do
      assert Workshops.get_question(template, 99) == nil
    end

    test "count_questions/1 returns the number of questions", %{template: template} do
      assert Workshops.count_questions(template) == 0

      {:ok, _} = Workshops.create_question(template, %{@valid_question_attrs | index: 0})

      {:ok, _} =
        Workshops.create_question(template, %{@valid_question_attrs | index: 1, title: "Q2"})

      assert Workshops.count_questions(template) == 2
    end
  end

  describe "get_template_with_questions/1" do
    test "returns template with preloaded questions" do
      {:ok, template} =
        Workshops.create_template(%{
          name: "Full Workshop",
          slug: "full-workshop",
          version: "1.0.0",
          default_duration_minutes: 180
        })

      {:ok, _} =
        Workshops.create_question(template, %{
          index: 0,
          title: "Q1",
          criterion_name: "C1",
          explanation: "E1",
          scale_type: "balance",
          scale_min: -5,
          scale_max: 5,
          optimal_value: 0
        })

      result = Workshops.get_template_with_questions(template.id)
      assert result.id == template.id
      assert length(result.questions) == 1
      assert hd(result.questions).title == "Q1"
    end
  end
end
