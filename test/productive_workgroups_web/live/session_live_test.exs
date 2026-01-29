defmodule ProductiveWorkgroupsWeb.SessionLiveTest do
  use ProductiveWorkgroupsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  alias ProductiveWorkgroups.{Notes, Scoring, Sessions, Workshops}

  describe "SessionLive.New" do
    setup do
      # Create the Six Criteria template for testing
      {:ok, template} =
        Workshops.create_template(%{
          name: "Six Criteria Test",
          slug: "six-criteria",
          version: "1.0.0",
          default_duration_minutes: 210
        })

      # Create at least one question for the template
      {:ok, _} =
        Workshops.create_question(template, %{
          index: 0,
          title: "Test Question",
          criterion_number: "1",
          criterion_name: "Test Criterion",
          explanation: "Test explanation",
          scale_type: "balance",
          scale_min: -5,
          scale_max: 5,
          optimal_value: 0
        })

      %{template: template}
    end

    test "renders the session creation form", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/session/new")

      assert html =~ "Create New Workshop"
      assert html =~ "Create Workshop"
      assert html =~ "Your Name (Facilitator)"
      assert html =~ "Session Timer"
    end
  end

  describe "SessionController.create" do
    setup do
      {:ok, template} =
        Workshops.create_template(%{
          name: "Controller Create Test",
          slug: "six-criteria",
          version: "1.0.0",
          default_duration_minutes: 210
        })

      %{template: template}
    end

    test "creates session and joins as facilitator", %{conn: conn} do
      conn =
        post(conn, ~p"/session/create", %{facilitator_name: "Facilitator Jane", duration: "120"})

      # Should redirect to the session page
      assert to = redirected_to(conn)
      assert to =~ ~r/\/session\/[A-Z0-9]+$/

      # Should have browser token
      assert get_session(conn, :browser_token)

      # Extract the code and verify participant is facilitator
      [_, code] = Regex.run(~r/\/session\/([A-Z0-9]+)$/, to)
      session = Sessions.get_session_by_code(code)
      participant = Sessions.get_facilitator(session)
      assert participant.name == "Facilitator Jane"
      assert participant.is_facilitator == true
    end

    test "requires a name to create session", %{conn: conn} do
      conn = post(conn, ~p"/session/create", %{facilitator_name: "", duration: "210"})

      assert redirected_to(conn) == "/session/new"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "name is required"
    end
  end

  describe "SessionController.create without template" do
    test "handles missing template gracefully", %{conn: conn} do
      # No template setup - simulates missing seeds
      conn = post(conn, ~p"/session/create", %{facilitator_name: "Test User", duration: "210"})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Workshop template not available"
    end
  end

  describe "SessionLive.Join" do
    setup do
      {:ok, template} =
        Workshops.create_template(%{
          name: "Join Test",
          slug: "join-test",
          version: "1.0.0",
          default_duration_minutes: 180
        })

      {:ok, session} = Sessions.create_session(template)
      %{session: session, template: template}
    end

    test "renders the join form", %{conn: conn, session: session} do
      {:ok, _view, html} = live(conn, ~p"/session/#{session.code}/join")

      assert html =~ "Join Workshop"
      assert html =~ session.code
      assert html =~ "Your Name"
    end

    test "handles invalid session code gracefully", %{conn: conn} do
      {:error, {:redirect, %{to: "/", flash: flash}}} =
        live(conn, ~p"/session/INVALID/join")

      assert flash["error"] =~ "Session not found"
    end
  end

  describe "SessionController.join" do
    setup do
      {:ok, template} =
        Workshops.create_template(%{
          name: "Controller Join Test",
          slug: "controller-join-test",
          version: "1.0.0",
          default_duration_minutes: 180
        })

      {:ok, session} = Sessions.create_session(template)
      %{session: session, template: template}
    end

    test "joins session with valid name and redirects", %{conn: conn, session: session} do
      conn = post(conn, ~p"/session/#{session.code}/join", %{participant: %{name: "Alice"}})

      assert redirected_to(conn) == "/session/#{session.code}"
      assert get_session(conn, :browser_token)
    end

    test "requires a name to join", %{conn: conn, session: session} do
      conn = post(conn, ~p"/session/#{session.code}/join", %{participant: %{name: ""}})

      assert redirected_to(conn) == "/session/#{session.code}/join"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Name is required"
    end

    test "handles invalid session code", %{conn: conn} do
      conn = post(conn, ~p"/session/INVALID/join", %{participant: %{name: "Alice"}})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Session not found"
    end
  end

  describe "SessionLive.Show" do
    setup do
      {:ok, template} =
        Workshops.create_template(%{
          name: "Show Test",
          slug: "show-test",
          version: "1.0.0",
          default_duration_minutes: 180
        })

      {:ok, _} =
        Workshops.create_question(template, %{
          index: 0,
          title: "Q1",
          criterion_number: "1",
          criterion_name: "C1",
          explanation: "E1",
          scale_type: "balance",
          scale_min: -5,
          scale_max: 5,
          optimal_value: 0
        })

      {:ok, session} = Sessions.create_session(template)
      {:ok, participant} = Sessions.join_session(session, "Alice", Ecto.UUID.generate())

      %{session: session, participant: participant, template: template}
    end

    test "redirects to join if no browser token", %{conn: conn, session: session} do
      {:error, {:redirect, %{to: to}}} = live(conn, ~p"/session/#{session.code}")
      assert to == "/session/#{session.code}/join"
    end

    test "renders lobby phase for participants", %{
      conn: conn,
      session: session,
      participant: participant
    } do
      # Set the browser token in the session
      conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> put_session(:browser_token, participant.browser_token)

      {:ok, _view, html} = live(conn, ~p"/session/#{session.code}")

      assert html =~ "Waiting Room"
      assert html =~ "Alice"
    end

    test "shows participant list in lobby", %{
      conn: conn,
      session: session,
      participant: participant
    } do
      # Add another participant
      {:ok, _p2} = Sessions.join_session(session, "Bob", Ecto.UUID.generate())

      conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> put_session(:browser_token, participant.browser_token)

      {:ok, _view, html} = live(conn, ~p"/session/#{session.code}")

      assert html =~ "Alice"
      assert html =~ "Bob"
    end

    test "handles invalid session code", %{conn: conn} do
      conn = Plug.Test.init_test_session(conn, %{})

      {:error, {:redirect, %{to: "/", flash: flash}}} =
        live(conn, ~p"/session/BADCODE")

      assert flash["error"] =~ "Session not found"
    end

    test "shows Start Workshop button for facilitator", %{conn: conn, session: session} do
      # Create a facilitator
      facilitator_token = Ecto.UUID.generate()

      {:ok, _facilitator} =
        Sessions.join_session(session, "Lead", facilitator_token, is_facilitator: true)

      conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> put_session(:browser_token, facilitator_token)

      {:ok, _view, html} = live(conn, ~p"/session/#{session.code}")

      assert html =~ "Start Workshop"
      assert html =~ "Facilitator"
    end

    test "does not show Start Workshop button for regular participant", %{
      conn: conn,
      session: session,
      participant: participant
    } do
      conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> put_session(:browser_token, participant.browser_token)

      {:ok, _view, html} = live(conn, ~p"/session/#{session.code}")

      refute html =~ "Start Workshop"
      assert html =~ "Waiting for the facilitator"
    end

    test "facilitator can start the workshop", %{conn: conn, session: session} do
      facilitator_token = Ecto.UUID.generate()

      {:ok, _facilitator} =
        Sessions.join_session(session, "Lead", facilitator_token, is_facilitator: true)

      conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> put_session(:browser_token, facilitator_token)

      {:ok, view, _html} = live(conn, ~p"/session/#{session.code}")

      # Click Start Workshop
      html = render_click(view, "start_workshop")

      # Should transition to intro phase
      assert html =~ "Welcome to the Six Criteria Workshop"
    end
  end

  describe "Notes capture in scoring phase" do
    setup do
      {:ok, template} =
        Workshops.create_template(%{
          name: "Notes Test",
          slug: "notes-test",
          version: "1.0.0",
          default_duration_minutes: 180
        })

      # Add a question
      {:ok, _} =
        Workshops.create_question(template, %{
          index: 0,
          title: "Test Question",
          criterion_number: "1",
          criterion_name: "Test Criterion",
          explanation: "Test explanation",
          scale_type: "balance",
          scale_min: -5,
          scale_max: 5,
          optimal_value: 0,
          discussion_prompts: ["What do you think?"]
        })

      {:ok, session} = Sessions.create_session(template)

      # Create facilitator
      facilitator_token = Ecto.UUID.generate()

      {:ok, facilitator} =
        Sessions.join_session(session, "Facilitator", facilitator_token, is_facilitator: true)

      # Create participant
      participant_token = Ecto.UUID.generate()
      {:ok, participant} = Sessions.join_session(session, "Alice", participant_token)

      # Advance session to scoring phase
      {:ok, session} = Sessions.start_session(session)
      {:ok, session} = Sessions.advance_to_scoring(session)

      %{
        session: session,
        template: template,
        facilitator: facilitator,
        facilitator_token: facilitator_token,
        participant: participant,
        participant_token: participant_token
      }
    end

    test "shows notes section when toggle button is clicked", ctx do
      # Submit scores for both participants
      {:ok, _} = Scoring.submit_score(ctx.session, ctx.facilitator, 0, 2)
      {:ok, _} = Scoring.submit_score(ctx.session, ctx.participant, 0, -1)

      conn =
        build_conn()
        |> Plug.Test.init_test_session(%{})
        |> put_session(:browser_token, ctx.facilitator_token)

      {:ok, view, html} = live(conn, ~p"/session/#{ctx.session.code}")

      # Notes are hidden by default
      refute html =~ "Capture a key discussion point"
      # Toggle button should be visible
      assert html =~ "Take Notes"

      # Click toggle to show notes
      html = view |> element("button", "Take Notes") |> render_click()

      assert html =~ "Discussion Notes"
      assert html =~ "Capture a key discussion point"
    end

    test "participants can add notes", ctx do
      # Submit scores for both participants
      {:ok, _} = Scoring.submit_score(ctx.session, ctx.facilitator, 0, 2)
      {:ok, _} = Scoring.submit_score(ctx.session, ctx.participant, 0, -1)

      conn =
        build_conn()
        |> Plug.Test.init_test_session(%{})
        |> put_session(:browser_token, ctx.participant_token)

      {:ok, view, _html} = live(conn, ~p"/session/#{ctx.session.code}")

      # Toggle notes section visible
      view |> element("button", "Take Notes") |> render_click()

      # Type a note
      view |> element("input[name=note]") |> render_change(%{value: "This is a test note"})

      # Submit the note
      html = render_submit(view, "add_note", %{})

      assert html =~ "This is a test note"
      assert html =~ "Alice"

      # Verify note was persisted
      notes = Notes.list_notes_for_question(ctx.session, 0)
      assert length(notes) == 1
      assert hd(notes).content == "This is a test note"
    end

    test "participants can delete notes", ctx do
      # Submit scores
      {:ok, _} = Scoring.submit_score(ctx.session, ctx.facilitator, 0, 2)
      {:ok, _} = Scoring.submit_score(ctx.session, ctx.participant, 0, -1)

      # Create a note
      {:ok, note} =
        Notes.create_note(ctx.session, 0, %{content: "Delete me", author_name: "Alice"})

      conn =
        build_conn()
        |> Plug.Test.init_test_session(%{})
        |> put_session(:browser_token, ctx.participant_token)

      {:ok, view, _html} = live(conn, ~p"/session/#{ctx.session.code}")

      # Toggle notes section visible
      view |> element("button", "Take Notes") |> render_click()

      # Delete the note
      html = render_click(view, "delete_note", %{"id" => note.id})

      refute html =~ "Delete me"

      # Verify note was deleted
      notes = Notes.list_notes_for_question(ctx.session, 0)
      assert notes == []
    end
  end

  describe "Facilitator role display" do
    setup do
      {:ok, template} =
        Workshops.create_template(%{
          name: "Facilitator Role Test",
          slug: "facilitator-role-test",
          version: "1.0.0",
          default_duration_minutes: 180
        })

      {:ok, _} =
        Workshops.create_question(template, %{
          index: 0,
          title: "Test Question",
          criterion_number: "1",
          criterion_name: "Test Criterion",
          explanation: "Test explanation",
          scale_type: "balance",
          scale_min: -5,
          scale_max: 5,
          optimal_value: 0
        })

      {:ok, session} = Sessions.create_session(template)

      %{session: session, template: template}
    end

    test "facilitator who is participating shows only Facilitator badge", %{
      conn: conn,
      session: session
    } do
      # Create facilitator who is participating (is_observer: false - the default)
      facilitator_token = Ecto.UUID.generate()

      {:ok, _facilitator} =
        Sessions.join_session(session, "Lead", facilitator_token,
          is_facilitator: true,
          is_observer: false
        )

      conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> put_session(:browser_token, facilitator_token)

      {:ok, _view, html} = live(conn, ~p"/session/#{session.code}")

      # Should show Facilitator badge
      assert html =~ "Facilitator"
      # Should NOT show Observer badge
      refute html =~ "Observer"
    end

    test "facilitator who is observing shows only Observer badge, not both", %{
      conn: conn,
      session: session
    } do
      # Create facilitator who is observing
      facilitator_token = Ecto.UUID.generate()

      {:ok, _facilitator} =
        Sessions.join_session(session, "Lead", facilitator_token,
          is_facilitator: true,
          is_observer: true
        )

      conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> put_session(:browser_token, facilitator_token)

      {:ok, _view, html} = live(conn, ~p"/session/#{session.code}")

      # Should show Observer badge (gray background)
      assert html =~ "bg-gray-600"
      assert html =~ "Observer"
      # Should NOT show Facilitator badge (purple background) - they cannot be both
      # The facilitator badge uses bg-purple-600 class
      refute html =~ "bg-purple-600"
    end

    test "facilitator defaults to participating (is_observer: false)", %{session: session} do
      # Create facilitator without specifying is_observer
      facilitator_token = Ecto.UUID.generate()

      {:ok, facilitator} =
        Sessions.join_session(session, "Lead", facilitator_token, is_facilitator: true)

      # Default should be participating (not observing)
      assert facilitator.is_facilitator == true
      assert facilitator.is_observer == false
    end

    test "regular participant is neither facilitator nor observer by default", %{session: session} do
      participant_token = Ecto.UUID.generate()

      {:ok, participant} = Sessions.join_session(session, "Alice", participant_token)

      assert participant.is_facilitator == false
      assert participant.is_observer == false
    end

    test "observer participant shows Observer badge", %{conn: conn, session: session} do
      # Create an observer who is not a facilitator
      observer_token = Ecto.UUID.generate()

      {:ok, _observer} =
        Sessions.join_session(session, "Watcher", observer_token, is_observer: true)

      # Create a facilitator so we can view the session
      facilitator_token = Ecto.UUID.generate()

      {:ok, _facilitator} =
        Sessions.join_session(session, "Lead", facilitator_token, is_facilitator: true)

      conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> put_session(:browser_token, facilitator_token)

      {:ok, _view, html} = live(conn, ~p"/session/#{session.code}")

      # Observer participant should show Observer badge
      assert html =~ "Watcher"
      assert html =~ "Observer"
    end
  end

  describe "Mid-workshop transition" do
    setup do
      {:ok, template} =
        Workshops.create_template(%{
          name: "Transition Test",
          slug: "transition-test",
          version: "1.0.0",
          default_duration_minutes: 180
        })

      # Add questions 0-4 (need at least 5 questions to test transition)
      criterion_numbers = ["1", "2a", "2b", "3", "4"]

      for i <- 0..4 do
        scale_type = if i < 4, do: "balance", else: "maximal"
        scale_min = if i < 4, do: -5, else: 0
        scale_max = if i < 4, do: 5, else: 10
        optimal_value = if i < 4, do: 0, else: nil

        {:ok, _} =
          Workshops.create_question(template, %{
            index: i,
            title: "Question #{i + 1}",
            criterion_number: Enum.at(criterion_numbers, i),
            criterion_name: "Criterion #{i + 1}",
            explanation: "Explanation #{i + 1}",
            scale_type: scale_type,
            scale_min: scale_min,
            scale_max: scale_max,
            optimal_value: optimal_value,
            discussion_prompts: []
          })
      end

      {:ok, session} = Sessions.create_session(template)

      # Create facilitator
      facilitator_token = Ecto.UUID.generate()

      {:ok, facilitator} =
        Sessions.join_session(session, "Facilitator", facilitator_token, is_facilitator: true)

      # Advance to scoring and then to question 4 (index 3)
      {:ok, session} = Sessions.start_session(session)
      {:ok, session} = Sessions.advance_to_scoring(session)

      # Advance through questions 1-3
      {:ok, _} = Scoring.submit_score(session, facilitator, 0, 0)
      {:ok, session} = Sessions.advance_question(session)

      {:ok, _} = Scoring.submit_score(session, facilitator, 1, 0)
      {:ok, session} = Sessions.advance_question(session)

      {:ok, _} = Scoring.submit_score(session, facilitator, 2, 0)
      {:ok, session} = Sessions.advance_question(session)

      # Now at question 4 (index 3) - submitting and advancing should show transition
      {:ok, _} = Scoring.submit_score(session, facilitator, 3, 0)

      %{
        session: session,
        template: template,
        facilitator: facilitator,
        facilitator_token: facilitator_token
      }
    end

    test "shows mid-workshop transition when advancing from question 4 to 5", ctx do
      conn =
        build_conn()
        |> Plug.Test.init_test_session(%{})
        |> put_session(:browser_token, ctx.facilitator_token)

      {:ok, view, _html} = live(conn, ~p"/session/#{ctx.session.code}")

      # Click next question to advance past question 4
      html = render_click(view, "next_question")

      # Should show the transition screen
      assert html =~ "New Scoring Scale Ahead"
      assert html =~ "first four questions"
      assert html =~ "more is always better"
      assert html =~ "10 is optimal"
    end

    test "continue button dismisses transition and shows question 5", ctx do
      conn =
        build_conn()
        |> Plug.Test.init_test_session(%{})
        |> put_session(:browser_token, ctx.facilitator_token)

      {:ok, view, _html} = live(conn, ~p"/session/#{ctx.session.code}")

      # Advance to show transition
      render_click(view, "next_question")

      # Click continue
      html = render_click(view, "continue_past_transition")

      # Should now show question 5
      assert html =~ "Question 5"
      refute html =~ "New Scoring Scale Ahead"
    end
  end

  describe "Facilitator back button" do
    setup do
      {:ok, template} =
        Workshops.create_template(%{
          name: "Back Button Test",
          slug: "back-button-test",
          version: "1.0.0",
          default_duration_minutes: 180
        })

      # Add 8 questions
      criterion_numbers = ["1", "2a", "2b", "3", "4", "5a", "5b", "6"]

      for i <- 0..7 do
        scale_type = if i < 4, do: "balance", else: "maximal"
        scale_min = if i < 4, do: -5, else: 0
        scale_max = if i < 4, do: 5, else: 10
        optimal_value = if i < 4, do: 0, else: nil

        {:ok, _} =
          Workshops.create_question(template, %{
            index: i,
            title: "Question #{i + 1}",
            criterion_number: Enum.at(criterion_numbers, i),
            criterion_name: "Criterion #{i + 1}",
            explanation: "Explanation #{i + 1}",
            scale_type: scale_type,
            scale_min: scale_min,
            scale_max: scale_max,
            optimal_value: optimal_value,
            discussion_prompts: []
          })
      end

      {:ok, session} = Sessions.create_session(template)

      # Create facilitator
      facilitator_token = Ecto.UUID.generate()

      {:ok, facilitator} =
        Sessions.join_session(session, "Facilitator", facilitator_token, is_facilitator: true)

      # Create regular participant
      participant_token = Ecto.UUID.generate()
      {:ok, participant} = Sessions.join_session(session, "Alice", participant_token)

      %{
        session: session,
        template: template,
        facilitator: facilitator,
        facilitator_token: facilitator_token,
        participant: participant,
        participant_token: participant_token
      }
    end

    test "back button is not shown in lobby state", ctx do
      conn =
        build_conn()
        |> Plug.Test.init_test_session(%{})
        |> put_session(:browser_token, ctx.facilitator_token)

      {:ok, _view, html} = live(conn, ~p"/session/#{ctx.session.code}")

      # Back button should not be visible in lobby
      refute html =~ "go_back"
    end

    test "back button is not shown to regular participants", ctx do
      # Advance to scoring
      {:ok, session} = Sessions.start_session(ctx.session)
      {:ok, session} = Sessions.advance_to_scoring(session)
      {:ok, _} = Scoring.submit_score(session, ctx.facilitator, 0, 0)
      {:ok, _} = Scoring.submit_score(session, ctx.participant, 0, 0)
      {:ok, _session} = Sessions.advance_question(session)

      conn =
        build_conn()
        |> Plug.Test.init_test_session(%{})
        |> put_session(:browser_token, ctx.participant_token)

      {:ok, _view, html} = live(conn, ~p"/session/#{ctx.session.code}")

      # Back button should not be visible to regular participants
      refute html =~ "go_back"
    end

    test "back button is shown to facilitator in scoring state", ctx do
      # Advance to scoring question 2
      {:ok, session} = Sessions.start_session(ctx.session)
      {:ok, session} = Sessions.advance_to_scoring(session)
      {:ok, _} = Scoring.submit_score(session, ctx.facilitator, 0, 0)
      {:ok, _} = Scoring.submit_score(session, ctx.participant, 0, 0)
      {:ok, _session} = Sessions.advance_question(session)

      conn =
        build_conn()
        |> Plug.Test.init_test_session(%{})
        |> put_session(:browser_token, ctx.facilitator_token)

      {:ok, _view, html} = live(conn, ~p"/session/#{ctx.session.code}")

      # Back button should be visible
      assert html =~ "go_back"
      assert html =~ "Back"
    end

    test "facilitator can go back from question 2 to question 1", ctx do
      # Advance to scoring question 2
      {:ok, session} = Sessions.start_session(ctx.session)
      {:ok, session} = Sessions.advance_to_scoring(session)
      {:ok, _} = Scoring.submit_score(session, ctx.facilitator, 0, 0)
      {:ok, _} = Scoring.submit_score(session, ctx.participant, 0, 0)
      {:ok, _session} = Sessions.advance_question(session)

      conn =
        build_conn()
        |> Plug.Test.init_test_session(%{})
        |> put_session(:browser_token, ctx.facilitator_token)

      {:ok, view, html} = live(conn, ~p"/session/#{ctx.session.code}")

      # Should be at question 2
      assert html =~ "Question 2 of 8"

      # Click back
      html = render_click(view, "go_back")

      # Should now be at question 1
      assert html =~ "Question 1 of 8"
    end

    test "going back from results page unreveals scores so participants can change them", ctx do
      # Start session and advance to scoring
      {:ok, session} = Sessions.start_session(ctx.session)
      {:ok, session} = Sessions.advance_to_scoring(session)
      {:ok, _} = Scoring.submit_score(session, ctx.facilitator, 0, 2)
      {:ok, _} = Scoring.submit_score(session, ctx.participant, 0, -1)
      # Explicitly reveal scores (this happens automatically in the LiveView when all submit)
      :ok = Scoring.reveal_scores(session, 0)

      # Verify scores were revealed
      scores_before = Scoring.list_scores_for_question(session, 0)
      assert Enum.all?(scores_before, & &1.revealed)

      conn =
        build_conn()
        |> Plug.Test.init_test_session(%{})
        |> put_session(:browser_token, ctx.facilitator_token)

      # Load the page - should show results page since scores are revealed
      {:ok, view, html} = live(conn, ~p"/session/#{ctx.session.code}")
      assert html =~ "Discuss the results"

      # Go back from results page to scoring entry
      render_click(view, "go_back")

      # Verify scores are now unrevealed
      scores_after = Scoring.list_scores_for_question(session, 0)
      refute Enum.any?(scores_after, & &1.revealed)
    end

    test "facilitator can go back from question 1 to intro", ctx do
      {:ok, session} = Sessions.start_session(ctx.session)
      {:ok, _session} = Sessions.advance_to_scoring(session)

      conn =
        build_conn()
        |> Plug.Test.init_test_session(%{})
        |> put_session(:browser_token, ctx.facilitator_token)

      {:ok, view, html} = live(conn, ~p"/session/#{ctx.session.code}")

      # Should be at question 1
      assert html =~ "Question 1 of 8"

      # Click back
      html = render_click(view, "go_back")

      # Should now be at intro (step 4 - safe space)
      assert html =~ "Creating a Safe Space"
    end

    test "facilitator can go back from summary to last question", ctx do
      # Advance to summary
      {:ok, session} = Sessions.start_session(ctx.session)
      {:ok, session} = Sessions.advance_to_scoring(session)
      {:ok, _session} = Sessions.advance_to_summary(session)

      conn =
        build_conn()
        |> Plug.Test.init_test_session(%{})
        |> put_session(:browser_token, ctx.facilitator_token)

      {:ok, view, html} = live(conn, ~p"/session/#{ctx.session.code}")

      # Should be at summary
      assert html =~ "Workshop Summary"

      # Click back
      html = render_click(view, "go_back")

      # Should now be at last question (question 8)
      assert html =~ "Question 8 of 8"
    end

    test "facilitator can go back from actions to summary", ctx do
      # Advance to actions
      {:ok, session} = Sessions.start_session(ctx.session)
      {:ok, session} = Sessions.advance_to_scoring(session)
      {:ok, session} = Sessions.advance_to_summary(session)
      {:ok, _session} = Sessions.advance_to_actions(session)

      conn =
        build_conn()
        |> Plug.Test.init_test_session(%{})
        |> put_session(:browser_token, ctx.facilitator_token)

      {:ok, view, html} = live(conn, ~p"/session/#{ctx.session.code}")

      # Should be at actions
      assert html =~ "Action Items"

      # Click back
      html = render_click(view, "go_back")

      # Should now be at summary
      assert html =~ "Workshop Summary"
    end

    test "back button is not shown in completed state", ctx do
      # Advance to completed
      {:ok, session} = Sessions.start_session(ctx.session)
      {:ok, session} = Sessions.advance_to_scoring(session)
      {:ok, session} = Sessions.advance_to_summary(session)
      {:ok, session} = Sessions.advance_to_actions(session)
      {:ok, _session} = Sessions.complete_session(session)

      conn =
        build_conn()
        |> Plug.Test.init_test_session(%{})
        |> put_session(:browser_token, ctx.facilitator_token)

      {:ok, _view, html} = live(conn, ~p"/session/#{ctx.session.code}")

      # Should be at completed
      assert html =~ "Workshop Complete"

      # Back button should not be visible
      refute html =~ "go_back"
    end
  end
end
