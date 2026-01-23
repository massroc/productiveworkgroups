defmodule ProductiveWorkgroupsWeb.HomeLiveTest do
  use ProductiveWorkgroupsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "Home page" do
    test "renders welcome message", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/")

      assert html =~ "Productive Work Groups"
      assert html =~ "Six Criteria of Productive Work"
      assert has_element?(view, "a", "Start New Workshop")
    end

    test "has link to create new session", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, ~s(a[href="/session/new"]))
    end
  end
end
