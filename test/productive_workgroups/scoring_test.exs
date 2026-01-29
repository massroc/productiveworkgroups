defmodule ProductiveWorkgroups.ScoringTest do
  use ProductiveWorkgroups.DataCase, async: true

  alias ProductiveWorkgroups.Scoring
  alias ProductiveWorkgroups.Scoring.Score
  alias ProductiveWorkgroups.{Sessions, Workshops}

  describe "scores" do
    setup do
      {:ok, template} =
        Workshops.create_template(%{
          name: "Test Workshop",
          slug: "test-scoring-workshop",
          version: "1.0.0",
          default_duration_minutes: 180
        })

      # Create balance scale question (Q1: -5 to 5, optimal 0)
      {:ok, _q1} =
        Workshops.create_question(template, %{
          index: 0,
          title: "Elbow Room",
          criterion_number: "1",
          criterion_name: "Autonomy",
          explanation: "Test",
          scale_type: "balance",
          scale_min: -5,
          scale_max: 5,
          optimal_value: 0
        })

      # Create maximal scale question (Q2: 0 to 10, more is better)
      {:ok, _q2} =
        Workshops.create_question(template, %{
          index: 1,
          title: "Mutual Support",
          criterion_number: "4",
          criterion_name: "Support",
          explanation: "Test",
          scale_type: "maximal",
          scale_min: 0,
          scale_max: 10,
          optimal_value: nil
        })

      {:ok, session} = Sessions.create_session(template)
      {:ok, participant} = Sessions.join_session(session, "Alice", Ecto.UUID.generate())

      %{session: session, participant: participant, template: template}
    end

    test "submit_score/4 creates a score", %{session: session, participant: participant} do
      assert {:ok, %Score{} = score} = Scoring.submit_score(session, participant, 0, 3)
      assert score.value == 3
      assert score.question_index == 0
      assert score.participant_id == participant.id
      assert score.session_id == session.id
      assert score.revealed == false
      assert score.submitted_at != nil
    end

    test "submit_score/4 updates existing score", %{session: session, participant: participant} do
      {:ok, score1} = Scoring.submit_score(session, participant, 0, 3)
      {:ok, score2} = Scoring.submit_score(session, participant, 0, -2)

      assert score1.id == score2.id
      assert score2.value == -2
    end

    test "submit_score/4 validates balance scale range", %{
      session: session,
      participant: participant
    } do
      # Balance scale Q1 is -5 to 5
      assert {:ok, _} = Scoring.submit_score(session, participant, 0, -5)
      assert {:ok, _} = Scoring.submit_score(session, participant, 0, 5)
      assert {:error, changeset} = Scoring.submit_score(session, participant, 0, -6)
      assert "must be between -5 and 5" in errors_on(changeset).value
      assert {:error, changeset} = Scoring.submit_score(session, participant, 0, 6)
      assert "must be between -5 and 5" in errors_on(changeset).value
    end

    test "submit_score/4 validates maximal scale range", %{
      session: session,
      participant: participant
    } do
      # Maximal scale Q2 is 0 to 10
      assert {:ok, _} = Scoring.submit_score(session, participant, 1, 0)
      assert {:ok, _} = Scoring.submit_score(session, participant, 1, 10)
      assert {:error, changeset} = Scoring.submit_score(session, participant, 1, -1)
      assert "must be between 0 and 10" in errors_on(changeset).value
      assert {:error, changeset} = Scoring.submit_score(session, participant, 1, 11)
      assert "must be between 0 and 10" in errors_on(changeset).value
    end

    test "get_score/3 retrieves a score", %{session: session, participant: participant} do
      {:ok, score} = Scoring.submit_score(session, participant, 0, 3)
      assert Scoring.get_score(session, participant, 0).id == score.id
    end

    test "get_score/3 returns nil when not found", %{session: session, participant: participant} do
      assert Scoring.get_score(session, participant, 99) == nil
    end

    test "list_scores_for_question/2 returns all scores", %{
      session: session,
      participant: participant
    } do
      {:ok, p2} = Sessions.join_session(session, "Bob", Ecto.UUID.generate())

      {:ok, _} = Scoring.submit_score(session, participant, 0, 3)
      {:ok, _} = Scoring.submit_score(session, p2, 0, -1)

      scores = Scoring.list_scores_for_question(session, 0)
      assert length(scores) == 2
    end

    test "reveal_scores/2 marks all scores as revealed", %{
      session: session,
      participant: participant
    } do
      {:ok, p2} = Sessions.join_session(session, "Bob", Ecto.UUID.generate())

      {:ok, _} = Scoring.submit_score(session, participant, 0, 3)
      {:ok, _} = Scoring.submit_score(session, p2, 0, -1)

      :ok = Scoring.reveal_scores(session, 0)

      scores = Scoring.list_scores_for_question(session, 0)
      assert Enum.all?(scores, & &1.revealed)
    end

    test "all_scored?/2 checks if all active participants scored", %{
      session: session,
      participant: participant
    } do
      {:ok, p2} = Sessions.join_session(session, "Bob", Ecto.UUID.generate())

      refute Scoring.all_scored?(session, 0)

      {:ok, _} = Scoring.submit_score(session, participant, 0, 3)
      refute Scoring.all_scored?(session, 0)

      {:ok, _} = Scoring.submit_score(session, p2, 0, -1)
      assert Scoring.all_scored?(session, 0)
    end

    test "count_scores/2 returns score count", %{session: session, participant: participant} do
      assert Scoring.count_scores(session, 0) == 0

      {:ok, _} = Scoring.submit_score(session, participant, 0, 3)
      assert Scoring.count_scores(session, 0) == 1
    end
  end

  describe "score aggregation" do
    setup do
      {:ok, template} =
        Workshops.create_template(%{
          name: "Aggregation Workshop",
          slug: "test-aggregation",
          version: "1.0.0",
          default_duration_minutes: 180
        })

      {:ok, _q1} =
        Workshops.create_question(template, %{
          index: 0,
          title: "Q1",
          criterion_number: "1",
          criterion_name: "C1",
          explanation: "Test",
          scale_type: "balance",
          scale_min: -5,
          scale_max: 5,
          optimal_value: 0
        })

      {:ok, session} = Sessions.create_session(template)
      {:ok, p1} = Sessions.join_session(session, "Alice", Ecto.UUID.generate())
      {:ok, p2} = Sessions.join_session(session, "Bob", Ecto.UUID.generate())
      {:ok, p3} = Sessions.join_session(session, "Carol", Ecto.UUID.generate())

      %{session: session, participants: [p1, p2, p3]}
    end

    test "calculate_average/2 computes mean score", %{
      session: session,
      participants: [p1, p2, p3]
    } do
      {:ok, _} = Scoring.submit_score(session, p1, 0, 3)
      {:ok, _} = Scoring.submit_score(session, p2, 0, 0)
      {:ok, _} = Scoring.submit_score(session, p3, 0, -3)

      assert Scoring.calculate_average(session, 0) == 0.0
    end

    test "calculate_average/2 returns nil when no scores", %{session: session} do
      assert Scoring.calculate_average(session, 0) == nil
    end

    test "calculate_spread/2 computes min and max", %{
      session: session,
      participants: [p1, p2, p3]
    } do
      {:ok, _} = Scoring.submit_score(session, p1, 0, 3)
      {:ok, _} = Scoring.submit_score(session, p2, 0, 0)
      {:ok, _} = Scoring.submit_score(session, p3, 0, -3)

      assert Scoring.calculate_spread(session, 0) == {-3, 3}
    end

    test "calculate_spread/2 returns nil when no scores", %{session: session} do
      assert Scoring.calculate_spread(session, 0) == nil
    end

    test "get_score_summary/2 returns comprehensive summary", %{
      session: session,
      participants: [p1, p2, p3]
    } do
      {:ok, _} = Scoring.submit_score(session, p1, 0, 4)
      {:ok, _} = Scoring.submit_score(session, p2, 0, 2)
      {:ok, _} = Scoring.submit_score(session, p3, 0, 0)

      summary = Scoring.get_score_summary(session, 0)

      assert summary.count == 3
      assert summary.average == 2.0
      assert summary.min == 0
      assert summary.max == 4
      assert summary.spread == 4
    end
  end

  describe "traffic light colors" do
    test "balance scale - green for optimal range (±0-1)" do
      assert Scoring.traffic_light_color("balance", 0, 0) == :green
      assert Scoring.traffic_light_color("balance", 1, 0) == :green
      assert Scoring.traffic_light_color("balance", -1, 0) == :green
    end

    test "balance scale - amber for moderate deviation (±2-3)" do
      assert Scoring.traffic_light_color("balance", 2, 0) == :amber
      assert Scoring.traffic_light_color("balance", -2, 0) == :amber
      assert Scoring.traffic_light_color("balance", 3, 0) == :amber
      assert Scoring.traffic_light_color("balance", -3, 0) == :amber
    end

    test "balance scale - red for high deviation (±4-5)" do
      assert Scoring.traffic_light_color("balance", 4, 0) == :red
      assert Scoring.traffic_light_color("balance", -4, 0) == :red
      assert Scoring.traffic_light_color("balance", 5, 0) == :red
      assert Scoring.traffic_light_color("balance", -5, 0) == :red
    end

    test "maximal scale - green for high scores (7-10)" do
      assert Scoring.traffic_light_color("maximal", 7, nil) == :green
      assert Scoring.traffic_light_color("maximal", 8, nil) == :green
      assert Scoring.traffic_light_color("maximal", 9, nil) == :green
      assert Scoring.traffic_light_color("maximal", 10, nil) == :green
    end

    test "maximal scale - amber for medium scores (4-6)" do
      assert Scoring.traffic_light_color("maximal", 4, nil) == :amber
      assert Scoring.traffic_light_color("maximal", 5, nil) == :amber
      assert Scoring.traffic_light_color("maximal", 6, nil) == :amber
    end

    test "maximal scale - red for low scores (0-3)" do
      assert Scoring.traffic_light_color("maximal", 0, nil) == :red
      assert Scoring.traffic_light_color("maximal", 1, nil) == :red
      assert Scoring.traffic_light_color("maximal", 2, nil) == :red
      assert Scoring.traffic_light_color("maximal", 3, nil) == :red
    end
  end

  describe "session score summary" do
    setup do
      {:ok, template} =
        Workshops.create_template(%{
          name: "Summary Workshop",
          slug: "test-summary",
          version: "1.0.0",
          default_duration_minutes: 180
        })

      criterion_numbers = ["1", "2a", "2b", "3", "4", "5a", "5b", "6"]

      for i <- 0..7 do
        scale_type = if i < 4, do: "balance", else: "maximal"
        scale_min = if i < 4, do: -5, else: 0
        scale_max = if i < 4, do: 5, else: 10
        optimal = if i < 4, do: 0, else: nil

        Workshops.create_question(template, %{
          index: i,
          title: "Q#{i + 1}",
          criterion_number: Enum.at(criterion_numbers, i),
          criterion_name: "C#{i + 1}",
          explanation: "Test",
          scale_type: scale_type,
          scale_min: scale_min,
          scale_max: scale_max,
          optimal_value: optimal
        })
      end

      {:ok, session} = Sessions.create_session(template)
      {:ok, participant} = Sessions.join_session(session, "Alice", Ecto.UUID.generate())

      %{session: session, participant: participant, template: template}
    end

    test "get_all_scores_summary/1 returns summaries for all questions", %{
      session: session,
      participant: participant,
      template: template
    } do
      # Submit scores for all 8 questions
      for i <- 0..7 do
        value = if i < 4, do: Enum.random(-5..5), else: Enum.random(0..10)
        Scoring.submit_score(session, participant, i, value)
      end

      summaries = Scoring.get_all_scores_summary(session, template)

      assert length(summaries) == 8
      assert Enum.all?(summaries, fn s -> s.count == 1 end)
    end
  end
end
