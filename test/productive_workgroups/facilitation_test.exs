defmodule ProductiveWorkgroups.FacilitationTest do
  use ProductiveWorkgroups.DataCase, async: true

  alias ProductiveWorkgroups.Facilitation
  alias ProductiveWorkgroups.Facilitation.Timer
  alias ProductiveWorkgroups.{Sessions, Workshops}

  describe "timers" do
    setup do
      {:ok, template} =
        Workshops.create_template(%{
          name: "Facilitation Test Workshop",
          slug: "test-facilitation",
          version: "1.0.0",
          default_duration_minutes: 180
        })

      {:ok, session} = Sessions.create_session(template)
      %{session: session}
    end

    test "create_timer/3 creates a timer for a phase", %{session: session} do
      assert {:ok, %Timer{} = timer} =
               Facilitation.create_timer(session, "intro", 300)

      assert timer.phase == "intro"
      assert timer.duration_seconds == 300
      assert timer.remaining_seconds == 300
      assert timer.status == "stopped"
      assert timer.session_id == session.id
    end

    test "create_timer/3 enforces unique phase per session", %{session: session} do
      {:ok, _} = Facilitation.create_timer(session, "intro", 300)

      assert {:error, changeset} = Facilitation.create_timer(session, "intro", 600)
      assert "has already been taken" in errors_on(changeset).phase
    end

    test "get_timer/2 retrieves a timer by phase", %{session: session} do
      {:ok, timer} = Facilitation.create_timer(session, "intro", 300)

      assert Facilitation.get_timer(session, "intro").id == timer.id
    end

    test "get_timer/2 returns nil for non-existent phase", %{session: session} do
      assert Facilitation.get_timer(session, "nonexistent") == nil
    end

    test "start_timer/1 starts a stopped timer", %{session: session} do
      {:ok, timer} = Facilitation.create_timer(session, "intro", 300)
      assert timer.status == "stopped"

      {:ok, started} = Facilitation.start_timer(timer)
      assert started.status == "running"
      assert started.started_at != nil
    end

    test "start_timer/1 resumes a paused timer", %{session: session} do
      {:ok, timer} = Facilitation.create_timer(session, "intro", 300)
      {:ok, timer} = Facilitation.start_timer(timer)
      {:ok, timer} = Facilitation.pause_timer(timer)
      assert timer.status == "paused"

      {:ok, resumed} = Facilitation.start_timer(timer)
      assert resumed.status == "running"
      assert resumed.paused_at == nil
    end

    test "pause_timer/1 pauses a running timer", %{session: session} do
      {:ok, timer} = Facilitation.create_timer(session, "intro", 300)
      {:ok, timer} = Facilitation.start_timer(timer)

      {:ok, paused} = Facilitation.pause_timer(timer)
      assert paused.status == "paused"
      assert paused.paused_at != nil
    end

    test "pause_timer/1 calculates remaining time", %{session: session} do
      {:ok, timer} = Facilitation.create_timer(session, "intro", 300)
      {:ok, timer} = Facilitation.start_timer(timer)

      # Simulate time passing by manually setting started_at to 60 seconds ago
      past_time = DateTime.add(DateTime.utc_now(), -60, :second) |> DateTime.truncate(:second)

      {:ok, timer} =
        timer
        |> Ecto.Changeset.change(started_at: past_time)
        |> Repo.update()

      {:ok, paused} = Facilitation.pause_timer(timer)
      # Should have ~240 seconds remaining (300 - 60)
      assert paused.remaining_seconds >= 238 and paused.remaining_seconds <= 242
    end

    test "stop_timer/1 stops a running timer", %{session: session} do
      {:ok, timer} = Facilitation.create_timer(session, "intro", 300)
      {:ok, timer} = Facilitation.start_timer(timer)

      {:ok, stopped} = Facilitation.stop_timer(timer)
      assert stopped.status == "stopped"
    end

    test "reset_timer/1 resets to initial duration", %{session: session} do
      {:ok, timer} = Facilitation.create_timer(session, "intro", 300)
      {:ok, timer} = Facilitation.start_timer(timer)
      {:ok, timer} = Facilitation.pause_timer(timer)

      # Manually reduce remaining time
      {:ok, timer} =
        timer
        |> Ecto.Changeset.change(remaining_seconds: 100)
        |> Repo.update()

      {:ok, reset} = Facilitation.reset_timer(timer)
      assert reset.remaining_seconds == 300
      assert reset.status == "stopped"
      assert reset.started_at == nil
    end

    test "mark_exceeded/1 marks timer as exceeded", %{session: session} do
      {:ok, timer} = Facilitation.create_timer(session, "intro", 300)
      {:ok, timer} = Facilitation.start_timer(timer)

      {:ok, exceeded} = Facilitation.mark_exceeded(timer)
      assert exceeded.status == "exceeded"
      assert exceeded.remaining_seconds == 0
    end

    test "list_timers/1 returns all timers for a session", %{session: session} do
      {:ok, _} = Facilitation.create_timer(session, "intro", 300)
      {:ok, _} = Facilitation.create_timer(session, "question_1", 180)
      {:ok, _} = Facilitation.create_timer(session, "question_2", 180)

      timers = Facilitation.list_timers(session)
      assert length(timers) == 3
    end

    test "get_or_create_timer/3 returns existing timer", %{session: session} do
      {:ok, timer} = Facilitation.create_timer(session, "intro", 300)

      {:ok, result} = Facilitation.get_or_create_timer(session, "intro", 600)
      assert result.id == timer.id
      # Original, not 600
      assert result.duration_seconds == 300
    end

    test "get_or_create_timer/3 creates new timer if not exists", %{session: session} do
      {:ok, timer} = Facilitation.get_or_create_timer(session, "intro", 300)
      assert timer.phase == "intro"
      assert timer.duration_seconds == 300
    end

    test "calculate_remaining/1 returns remaining seconds for running timer", %{session: session} do
      {:ok, timer} = Facilitation.create_timer(session, "intro", 300)
      {:ok, timer} = Facilitation.start_timer(timer)

      # Simulate time passing
      past_time = DateTime.add(DateTime.utc_now(), -60, :second) |> DateTime.truncate(:second)

      {:ok, timer} =
        timer
        |> Ecto.Changeset.change(started_at: past_time)
        |> Repo.update()

      remaining = Facilitation.calculate_remaining(timer)
      assert remaining >= 238 and remaining <= 242
    end

    test "calculate_remaining/1 returns stored value for stopped timer", %{session: session} do
      {:ok, timer} = Facilitation.create_timer(session, "intro", 300)
      assert Facilitation.calculate_remaining(timer) == 300
    end

    test "calculate_remaining/1 returns stored value for paused timer", %{session: session} do
      {:ok, timer} = Facilitation.create_timer(session, "intro", 300)
      {:ok, timer} = Facilitation.start_timer(timer)

      # Simulate pause after 60 seconds
      past_time = DateTime.add(DateTime.utc_now(), -60, :second) |> DateTime.truncate(:second)

      {:ok, timer} =
        timer
        |> Ecto.Changeset.change(started_at: past_time, remaining_seconds: 240)
        |> Repo.update()

      {:ok, paused} = Facilitation.pause_timer(timer)
      assert Facilitation.calculate_remaining(paused) == paused.remaining_seconds
    end
  end

  describe "phase management" do
    setup do
      {:ok, template} =
        Workshops.create_template(%{
          name: "Phase Test Workshop",
          slug: "test-phases",
          version: "1.0.0",
          default_duration_minutes: 180
        })

      {:ok, session} = Sessions.create_session(template)
      %{session: session}
    end

    test "phase_name/1 returns descriptive phase names" do
      assert Facilitation.phase_name("intro") == "Introduction"
      assert Facilitation.phase_name("question_0") == "Question 1"
      assert Facilitation.phase_name("question_7") == "Question 8"
      assert Facilitation.phase_name("summary") == "Summary"
      assert Facilitation.phase_name("actions") == "Action Planning"
      assert Facilitation.phase_name("unknown") == "unknown"
    end

    test "suggested_duration/1 returns default durations in seconds" do
      # 10 minutes
      assert Facilitation.suggested_duration("intro") == 600
      # 15 minutes per question
      assert Facilitation.suggested_duration("question_0") == 900
      # 10 minutes
      assert Facilitation.suggested_duration("summary") == 600
      # 20 minutes
      assert Facilitation.suggested_duration("actions") == 1200
      # 5 minutes default
      assert Facilitation.suggested_duration("unknown") == 300
    end
  end
end
