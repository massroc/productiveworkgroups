defmodule ProductiveWorkgroupsWeb.SessionLiveTest do
  use ProductiveWorkgroupsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  alias ProductiveWorkgroups.{Workshops, Sessions}

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
      assert html =~ "Start Workshop"
    end

    test "creates a new session and redirects", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/session/new")

      # Submit the form - this triggers a live redirect to the join page
      assert {:error, {:live_redirect, %{to: to}}} =
               view
               |> form("#session-form", %{})
               |> render_submit()

      # Verify the redirect path matches expected pattern
      assert to =~ ~r/\/session\/[A-Z0-9]+\/join/
    end

    test "creates session with custom duration", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/session/new")

      assert {:error, {:live_redirect, %{to: to}}} =
               view
               |> form("#session-form", %{session: %{planned_duration_minutes: 120}})
               |> render_submit()

      assert to =~ ~r/\/session\/[A-Z0-9]+\/join/
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

    test "renders lobby phase for participants", %{conn: conn, session: session, participant: participant} do
      # Set the browser token in the session
      conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> put_session(:browser_token, participant.browser_token)

      {:ok, _view, html} = live(conn, ~p"/session/#{session.code}")

      assert html =~ "Waiting Room"
      assert html =~ "Alice"
    end

    test "shows participant list in lobby", %{conn: conn, session: session, participant: participant} do
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
  end
end
