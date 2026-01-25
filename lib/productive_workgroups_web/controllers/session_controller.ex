defmodule ProductiveWorkgroupsWeb.SessionController do
  @moduledoc """
  Controller for session actions that require setting plug session values.
  """
  use ProductiveWorkgroupsWeb, :controller

  alias ProductiveWorkgroups.Sessions
  alias ProductiveWorkgroups.Workshops

  @doc """
  Creates a new session and joins the creator as facilitator.
  """
  def create(conn, params) do
    facilitator_name = String.trim(params["facilitator_name"] || "")
    duration = params["duration"] || "210"

    with {:ok, name} <- validate_name(facilitator_name),
         {:ok, template} <- get_template(),
         {:ok, session} <-
           Sessions.create_session(template, %{
             planned_duration_minutes: String.to_integer(duration)
           }),
         browser_token <- Ecto.UUID.generate(),
         {:ok, _participant} <-
           Sessions.join_session(session, name, browser_token, is_facilitator: true) do
      conn
      |> put_session(:browser_token, browser_token)
      |> redirect(to: ~p"/session/#{session.code}")
    else
      {:error, :name_required} ->
        conn
        |> put_flash(:error, "Your name is required.")
        |> redirect(to: ~p"/session/new")

      {:error, :template_not_found} ->
        conn
        |> put_flash(:error, "Workshop template not available. Please contact support.")
        |> redirect(to: ~p"/")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Failed to create session. Please try again.")
        |> redirect(to: ~p"/session/new")
    end
  end

  @doc """
  Handles joining a session. Creates the participant and sets the browser_token in session.
  """
  def join(conn, %{"code" => code, "participant" => params}) do
    name = String.trim(params["name"] || "")

    with {:ok, session} <- get_session_by_code(code),
         {:ok, name} <- validate_name(name),
         browser_token <- Ecto.UUID.generate(),
         {:ok, _participant} <- Sessions.join_session(session, name, browser_token) do
      conn
      |> put_session(:browser_token, browser_token)
      |> redirect(to: ~p"/session/#{session.code}")
    else
      {:error, :session_not_found} ->
        conn
        |> put_flash(:error, "Session not found.")
        |> redirect(to: ~p"/")

      {:error, :name_required} ->
        conn
        |> put_flash(:error, "Name is required.")
        |> redirect(to: ~p"/session/#{code}/join")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Failed to join session. Please try again.")
        |> redirect(to: ~p"/session/#{code}/join")
    end
  end

  defp get_session_by_code(code) do
    case Sessions.get_session_by_code(code) do
      nil -> {:error, :session_not_found}
      session -> {:ok, session}
    end
  end

  defp get_template do
    case Workshops.get_template_by_slug("six-criteria") do
      nil -> {:error, :template_not_found}
      template -> {:ok, template}
    end
  end

  defp validate_name(""), do: {:error, :name_required}
  defp validate_name(name), do: {:ok, name}
end
