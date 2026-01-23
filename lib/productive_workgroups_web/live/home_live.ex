defmodule ProductiveWorkgroupsWeb.HomeLive do
  @moduledoc """
  Home page LiveView - entry point for creating new workshop sessions.
  """
  use ProductiveWorkgroupsWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Welcome")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-900 flex flex-col items-center justify-center px-4">
      <div class="max-w-2xl text-center">
        <h1 class="text-4xl font-bold text-white mb-4">
          Productive Work Groups
        </h1>
        <p class="text-xl text-gray-300 mb-8">
          A self-guided workshop for exploring the Six Criteria of Productive Work
        </p>

        <div class="space-y-4">
          <.link
            navigate={~p"/session/new"}
            class="inline-block w-full sm:w-auto px-8 py-4 bg-blue-600 hover:bg-blue-700 text-white font-semibold rounded-lg transition-colors"
          >
            Start New Workshop
          </.link>

          <p class="text-gray-400 text-sm">
            No account required. Your session link will be shareable with your team.
          </p>
        </div>
      </div>
    </div>
    """
  end
end
