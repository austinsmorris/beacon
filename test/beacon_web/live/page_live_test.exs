defmodule BeaconWeb.Live.PageLiveTest do
  use BeaconWeb.ConnCase, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  import Beacon.Fixtures

  setup_all do
    start_supervised!({Beacon.Loader, Beacon.Config.fetch!(:my_site)})
    :ok
  end

  defp create_page(_) do
    stylesheet_fixture()

    component_fixture(name: "sample_component")

    layout =
      layout_fixture(
        meta_tags: [
          %{"http-equiv" => "refresh", "content" => "300"}
        ]
      )

    Beacon.Content.publish_layout(layout)

    _page_home =
      published_page_fixture(
        layout_id: layout.id,
        path: "home",
        template: """
        <main>
          <h2>Some Values:</h2>
          <%= for val <- @beacon_live_data[:vals] do %>
            <%= my_component("sample_component", val: val) %>
          <% end %>

          <.form :let={f} for={%{}} as={:greeting} phx-submit="hello">
            Name: <%= text_input f, :name %>
            <%= submit "Hello" %>
          </.form>

          <%= if assigns[:message], do: assigns.message %>

          <%= dynamic_helper("upcase", %{name: "test_name"}) %>
        </main>
        """,
        meta_tags: [
          %{"name" => "csrf-token", "content" => "csrf-token-page"},
          %{"name" => "theme-color", "content" => "#3c790a", "media" => "(prefers-color-scheme: dark)"},
          %{"property" => "og:title", "content" => "Beacon"}
        ],
        events: [
          page_event_params()
        ],
        helpers: [
          page_helper_params()
        ]
      )

    _page_without_meta_tags =
      published_page_fixture(
        layout_id: layout.id,
        path: "without_meta_tags",
        template: """
        <main>
        </main>
        """,
        meta_tags: nil
      )

    Beacon.reload_site(:my_site)

    :ok
  end

  describe "meta tags" do
    setup [:create_page]

    test "merge layout, page, and site", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/home")

      expected =
        ~S"""
        <head>
          <meta name="csrf-token" content=".*"/>
          <meta content="#3c790a" media="\(prefers-color-scheme: dark\)" name="theme-color"/>
          <meta content="Beacon" property="og:title"/>
          <meta content="300" http-equiv="refresh"/>
          <meta charset="utf-8"/>
          <meta content="IE=edge" http-equiv="X-UA-Compatible"/>
          <meta content="width=device-width, initial-scale=1" name="viewport"/>
        """
        |> String.replace("\n", "")
        |> String.replace("  ", "")
        |> Regex.compile!()

      assert html =~ expected
    end

    test "do not overwrite csrf-token", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/home")

      refute html =~ "csrf-token-page"
    end

    test "render without meta tags", %{conn: conn} do
      assert {:ok, _view, _html} = live(conn, "/without_meta_tags")
    end
  end

  describe "render" do
    setup [:create_page]

    test "a given path", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/home")

      assert html =~ "<header>Page header</header>"
      assert html =~ ~s"<main><h2>Some Values:</h2>"
      assert html =~ "<footer>Page footer</footer>"
    end

    test "component", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/home")

      assert html =~ ~s(<span id="my-component-first">)
      assert html =~ ~s(<span id="my-component-second">)
      assert html =~ ~s(<span id="my-component-third">)
    end

    test "event", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/home")

      assert view
             |> form("form", %{greeting: %{name: "Beacon"}})
             |> render_submit() =~ "Hello Beacon"
    end

    test "helper", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/home")

      assert html =~ ~s(TEST_NAME)
    end

    test "raise when the given path doesn't exist", %{conn: conn} do
      assert_raise BeaconWeb.NotFoundError, fn ->
        {:ok, _view, _html} = live(conn, "/no_page_match")
      end
    end

    test "routes to custom live path", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/home")

      assert html =~ ~s(phx-socket="/custom_live")
    end
  end

  describe "page title" do
    test "on layout", %{conn: conn} do
      stylesheet_fixture()
      layout = published_layout_fixture(title: "layout_title")
      page = published_page_fixture(layout_id: layout.id, title: nil, path: "/layout_title")
      Beacon.Loader.load_page(page)

      {:ok, view, _html} = live(conn, "/layout_title")

      assert page_title(view) =~ "layout_title"
    end

    test "on layout (without stylesheet)", %{conn: conn} do
      # ensure no stylesheets are present
      assert Beacon.Repo.all(Beacon.Content.Stylesheet) == []

      # same test as above, as a sanity check
      layout = published_layout_fixture(title: "layout_title")
      page = published_page_fixture(layout_id: layout.id, title: nil, path: "/layout_title")
      Beacon.Loader.load_page(page)

      {:ok, view, _html} = live(conn, "/layout_title")

      assert page_title(view) =~ "layout_title"
    end

    test "on page overwrite layout", %{conn: conn} do
      stylesheet_fixture()
      layout = published_layout_fixture(title: "layout_title")
      page = published_page_fixture(layout_id: layout.id, title: "page_title", path: "/page_title")
      Beacon.Loader.load_page(page)

      {:ok, view, _html} = live(conn, "/page_title")

      assert page_title(view) =~ "page_title"
    end
  end

  describe "markdown" do
    test "page template", %{conn: conn} do
      stylesheet_fixture()
      layout = published_layout_fixture()
      page = published_page_fixture(layout_id: layout.id, format: "markdown", template: "# Title", path: "/markdown")
      Beacon.Loader.load_page(page)

      {:ok, view, _html} = live(conn, "/markdown")

      assert has_element?(view, "h1", "Title")
    end
  end
end
