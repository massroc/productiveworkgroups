defmodule ProductiveWorkgroupsWeb.SessionController do
  @moduledoc """
  Controller for session actions that require setting plug session values.
  """
  use ProductiveWorkgroupsWeb, :controller

  alias ProductiveWorkgroups.Sessions

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

  defp validate_name(""), do: {:error, :name_required}
  defp validate_name(name), do: {:ok, name}
end
