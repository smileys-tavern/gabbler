defmodule GabblerWeb.LiveComponent.SuggestionWidget do
  use Phoenix.LiveComponent

  alias Gabbler.TagTracker.TopContent


  def render(assigns) do
    ~L"""
      <% content = Enum.at(assigns[:top_content], assigns[:selected]) %>
      <%= case content do %>
        <% %TopContent{type: :post} = tc -> %>
          <%= render_post(assigns, tc) %>
        <% %TopContent{type: :room} = tc -> %>
          <%= render_room(assigns, tc) %>
        <% _ -> %>
          <div></div>
      <% end %>
    """
  end

  def render_post(assigns, %TopContent{imgs: [_, _, _|_] = i, thumbs: t, url: url, desc: desc}) do
    imgs = case assigns do
      %{mode: :banner} -> i
      _ -> t
    end

    ~L"""
      <div class="suggestions images-many animate__animated animate__fadeIn">
        <div class="images">
          <%= for i <- imgs do %>
            <div><a href="<%= url %>">
              <img src="<%= i %>" class="thumb" />
            </a></div>
          <% end %>
        </div>
        <div class="title-center-low-left">
          <a href="<%= url %>">TRENDING POST</a>
        </div>
        <div class="title-center-low-right">
        </div>
      </div>
    """
  end

  def render_post(assigns, %TopContent{imgs: [_|_] = i, thumbs: t, url: url, desc: desc, long: long}) do
    imgs = case assigns do
      %{mode: :banner} -> i
      _ -> t
    end

    ~L"""
      <div class="suggestions images-few animate__animated animate__fadeIn">
        <div class="images">
          <%= for i <- imgs do %>
            <div><a href="<%= url %>">
              <img src="<%= i %>" class="thumb-single" />
            </a></div>
          <% end %>
        </div>
        <div class="title-center-low-left">
          <a href="<%= url %>">TRENDING POST</a>
        </div>
        <div class="title-center-justified">
          <a href="<%= url %>"><%= desc %></a>
          <p><%= long %></p>
        </div>
      </div>
    """
  end

  def render_post(assigns, %TopContent{url: url, desc: desc, ext_url: ext_url, long: long}) do
    ~L"""
      <div class="suggestions text-only animate__animated animate__fadeIn">
        <div class="description">
          <%= long %><br />
          <a href="<%= ext_url %>"><%= ext_url %>➲</a>
        </div>
        <div class="title-center-low-left">
          <a href="<%= url %>">TRENDING POST</a>
        </div>
        <div class="title-center-justified">
          <a href="<%= url %>"><%= desc %></a>
        </div>
      </div>
    """
  end

  def render_room(assigns, %TopContent{url: url, desc: desc, imgs: imgs}) do
    ~L"""
      <div class="suggestions images-many suggestions-room animate__animated animate__fadeIn">
        <div class="background-image">
          <%= case imgs do %>
            <% [img] ->%>
              <a href="<%= url %>"><img src="<%= img %>" /></a>
            <% _ -> %>
              &nbsp;
          <% end %>
        </div>
        <div class="title-centered">
          <a href="<%= url %>"><%= url %></a> <%= String.slice(desc, 0, 77) %>..
        </div>
        <div class="title-center-low-left">
          <a href="<%= url %>">NEW ROOM</a>
        </div>
      </div>
    """
  end

  def preload([%{top_content: amt} = assigns]) do
    assigns = assigns
    |> Map.put(:top_content, Enum.take(Gabbler.TagTracker.top_content(), amt))
    |> Map.put(:mode, Map.get(assigns, :mode, :banner))

    [assigns]
  end
end