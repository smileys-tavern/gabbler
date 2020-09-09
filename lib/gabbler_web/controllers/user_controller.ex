defmodule GabblerWeb.UserController do
  use GabblerWeb, :controller

  alias Gabbler.Controller, as: GabController


  def index(conn, _params), do: render(conn, "index.html")

  def profile(conn, params) do
    conn
    |> GabController.assign_user(params)
    |> GabController.assign_to(:posts, &get_user_posts/1)
    |> GabController.assign_to(:rooms, &get_post_rooms/1)
    |> GabController.assign_to(:post_metas, &get_post_metas/1)
    |> GabController.render_if([:subject_user], &render_user_profile/1)
  end

  #def new(conn, params) do
  #  GabController.add_user_auth(%{}, params)
  #  |> register_or_signin()
  #  |> handle_signin(conn)
  #end

  #def delete(conn, _) do
  #  conn
  #  |> Guardian.Plug.sign_out()
  #  |> redirect(to: "/")
  #end

  # PRIVATE FUNCTIONS
  ###################
  defp render_user_profile(%{assigns: assigns} = conn) do
    conn
    |> render("profile.html", assigns)
  end

  defp get_user_posts(%{assigns: %{subject_user: %{id: user_id}}}) do
    Gabbler.Post.list(by_user: user_id, order_by: :inserted_at, only: :op)
  end

  defp get_user_posts(_), do: []

  defp get_post_rooms(%{assigns: %{posts: posts}}) when is_list(posts) do
    Gabbler.Post.map_rooms(posts)
  end
  
  defp get_post_rooms(_), do: %{}

  defp get_post_metas(%{assigns: %{posts: posts}}) when is_list(posts) do
    Gabbler.Post.map_meta(posts)
  end
  
  defp get_post_metas(_), do: %{}
end
