defmodule Beacon.ContentTest do
  use Beacon.DataCase
  import Beacon.Fixtures
  alias Beacon.Content
  alias Beacon.Content.Layout
  alias Beacon.Content.LayoutEvent
  alias Beacon.Content.LayoutSnapshot
  alias Beacon.Content.Page
  alias Beacon.Content.PageEvent
  alias Beacon.Content.PageSnapshot
  alias Beacon.Repo

  describe "layouts" do
    test "create layout should create a created event" do
      Content.create_layout!(%{
        site: "my_site",
        title: "test",
        body: "<p>layout</p>"
      })

      assert %LayoutEvent{event: :created} = Repo.one(LayoutEvent)
    end

    test "publish layout should create a published event" do
      layout = layout_fixture()

      assert {:ok, %Layout{}} = Content.publish_layout(layout)
      assert [_created, %LayoutEvent{event: :published}] = Repo.all(LayoutEvent)
    end

    test "publish layout should create a snapshot" do
      layout = layout_fixture(title: "snapshot test")

      assert {:ok, %Layout{}} = Content.publish_layout(layout)
      assert %LayoutSnapshot{layout: %Layout{title: "snapshot test"}} = Repo.one(LayoutSnapshot)
    end

    test "list published layouts" do
      # publish layout_a twice
      layout_a = layout_fixture(title: "layout_a v1")
      {:ok, layout_a} = Content.publish_layout(layout_a)
      {:ok, layout_a} = Content.update_layout(layout_a, %{"title" => "layout_a v2"})
      {:ok, _layout_a} = Content.publish_layout(layout_a)

      # do not publish layout_b
      _layout_b = layout_fixture(title: "layout_b v1")

      assert [%Layout{title: "layout_a v2"}] = Content.list_published_layouts(:my_site)
    end
  end

  describe "pages" do
    # TODO: require paths starting with / which will make this test fail
    test "create page with empty path" do
      layout = layout_fixture()

      assert {:ok, %Page{path: ""}} =
               Content.create_page(%{
                 site: "my_site",
                 path: "",
                 template: "<p>page</p>",
                 layout_id: layout.id
               })
    end

    test "create page should create a created event" do
      layout = layout_fixture()

      Content.create_page!(%{
        site: "my_site",
        path: "/",
        template: "<p>page</p>",
        layout_id: layout.id
      })

      assert %PageEvent{event: :created} = Repo.one(PageEvent)
    end

    test "publish page should create a published event" do
      page = page_fixture()

      assert {:ok, %Page{}} = Content.publish_page(page)
      assert [_created, %PageEvent{event: :published}] = Repo.all(PageEvent)
    end

    test "publish page should create a snapshot" do
      page = page_fixture(title: "snapshot test")

      assert {:ok, %Page{}} = Content.publish_page(page)
      assert %PageSnapshot{page: %Page{title: "snapshot test"}} = Repo.one(PageSnapshot)
    end

    test "list_published_pages" do
      # publish page_a twice
      page_a = page_fixture(path: "/a", title: "page_a v1")
      {:ok, page_a} = Content.publish_page(page_a)
      {:ok, page_a} = Content.update_page(page_a, %{"title" => "page_a v2"})
      {:ok, _page_a} = Content.publish_page(page_a)

      # publish and unpublish page_b
      page_b = page_fixture(path: "/b", title: "page_b v1")
      {:ok, page_b} = Content.publish_page(page_b)
      {:ok, _page_b} = Content.unpublish_page(page_b)

      # do not publish page_c
      _page_c = page_fixture(path: "/c", title: "page_c v1")

      assert [%Page{title: "page_a v2"}] = Content.list_published_pages(:my_site)
    end

    test "list_published_pages with same inserted_at missing usec" do
      page = page_fixture(path: "/d", title: "page v1")
      Beacon.Repo.query!("UPDATE beacon_page_events SET inserted_at = '2020-01-01'", [])
      Beacon.Repo.query!("UPDATE beacon_page_snapshots SET inserted_at = '2020-01-01'", [])

      assert Content.list_published_pages(:my_site) == []

      {:ok, _page} = Content.publish_page(page)
      Beacon.Repo.query!("UPDATE beacon_page_events SET inserted_at = '2020-01-01'", [])
      Beacon.Repo.query!("UPDATE beacon_page_snapshots SET inserted_at = '2020-01-01'", [])

      assert [%Page{title: "page v1"}] = Content.list_published_pages(:my_site)
    end

    test "get_page_status" do
      page = page_fixture()
      assert Content.get_page_status(page) == :created

      Content.publish_page(page)
      assert Content.get_page_status(page) == :published

      Content.unpublish_page(page)
      assert Content.get_page_status(page) == :unpublished

      Content.publish_page(page)
      assert Content.get_page_status(page) == :published
    end

    test "lifecycle after_create_page" do
      layout = layout_fixture(site: :lifecycle_test)

      Content.create_page!(%{
        site: "lifecycle_test",
        path: "/",
        template: "<p>page</p>",
        layout_id: layout.id
      })

      assert_receive :lifecycle_after_create_page
    end

    test "lifecycle after_update_page" do
      layout = layout_fixture(site: :lifecycle_test)

      page =
        Content.create_page!(%{
          site: "lifecycle_test",
          path: "/",
          template: "<p>page</p>",
          layout_id: layout.id
        })

      Content.update_page(page, %{template: "<p>page updated</p>"})

      assert_receive :lifecycle_after_create_page
      assert_receive :lifecycle_after_update_page
    end

    test "lifecycle after_publish_page" do
      layout = layout_fixture(site: :lifecycle_test)

      page =
        Content.create_page!(%{
          site: "lifecycle_test",
          path: "/",
          template: "<p>page</p>",
          layout_id: layout.id
        })

      Content.publish_page(page)

      assert_receive :lifecycle_after_create_page
      assert_receive :lifecycle_after_publish_page
    end
  end

  describe "snippets" do
    test "assigns" do
      assert Content.render_snippet(
               "page title is {{ page.title }}",
               %{page: %Page{title: "test"}}
             ) == {:ok, "page title is test"}

      assert Content.render_snippet(
               "author.id is {{ page.extra.author.id }}",
               %{page: %Page{extra: %{"author" => %{"id" => 1}}}}
             ) == {:ok, "author.id is 1"}
    end

    test "render helper" do
      snippet_helper_fixture(
        site: "my_site",
        name: "author_name",
        body:
          String.trim(~S"""
          author_id = get_in(assigns, ["page", "extra", "author_id"])
          "test_#{author_id}"
          """)
      )

      Beacon.Loader.load_snippet_helpers(:my_site)

      assert Content.render_snippet(
               "author name is {% helper 'author_name' %}",
               %{page: %Page{site: "my_site", extra: %{"author_id" => 1}}}
             ) == {:ok, "author name is test_1"}
    end
  end
end
