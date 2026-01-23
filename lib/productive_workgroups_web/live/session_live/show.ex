defmodule ProductiveWorkgroupsWeb.SessionLive.Show do
  @moduledoc """
  Main workshop LiveView - handles the full workshop flow.
  """
  use ProductiveWorkgroupsWeb, :live_view

  @impl true
  def mount(%{"code" => code}, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Workshop Session",
       session_code: code
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-900 flex flex-col items-center justify-center px-4">
      <div class="max-w-4xl w-full">
        <h1 class="text-2xl font-bold text-white mb-6 text-center">
          Workshop Session
        </h1>
        <p class="text-gray-400 text-center">
          Session code: <span class="font-mono text-white"><%= @session_code %></span>
        </p>
        <p class="text-gray-400 text-center mt-4">
          Workshop interface coming soon...
        </p>
      </div>
    </div>
    """
  end
end
