defmodule Beacon.Config do
  @moduledoc """
  Configuration for sites.

  See `new/1` for options and examples.

  """

  alias Beacon.Content
  alias Beacon.Registry

  @typedoc """
  Host application router
  """
  @type router :: module()

  @typedoc """
  A module that implements `Beacon.DataSource.Behaviour`, used to provide `@assigns` to pages.
  """
  @type data_source :: module() | nil

  @typedoc """
  A module that implements `Beacon.Authorization.Behaviour`, used to provide authorization rules for the admin backend.
  """
  @type authorization_source :: module()

  @typedoc """
  A module that implements `Beacon.RuntimeCSS`, used to compile CSS for pages.
  """
  @type css_compiler :: module()

  @typedoc """
  Path to a custom tailwind config. Note that this config file must include `<%= @beacon_content %>` in the `content` section, see `Beacon.TailwindCompiler` for more info.
  """
  @type tailwind_config :: Path.t()

  @typedoc """
  Path of a live socket where Beacon should connect to.
  """
  @type live_socket_path :: String.t()

  @typedoc """
  Check safety of Elixir code using https://github.com/TheFirstAvenger/safe_code
  """
  @type safe_code_check :: boolean()

  @typedoc """
  Register formats to handle templates, eg: `[{:heex, "HEEx (HTML)"}]`.

  Beacon provides two formats built-in, HEEx and Markdown, but you can register your own
  as long as you also implement the life-cycle stages `:load_template` and `:render_template`.

  The description is used on user interfaces as Beacon Admin.
  """
  @type template_formats :: [{format :: atom(), description :: String.t()}]

  @typedoc """
  Register specific media types allowed for upload. Catchalls are not allowed.
  """
  @type allowed_media_types :: [media_type :: String.t()]

  @typedoc """
  Register backends and validations for media types. Catchalls are allowed.
  """
  @type assets :: [{media_type :: String.t(), media_type_config()}]

  @typedoc """
  Individual media type configs
  """
  @type media_type_config :: [
          {:backends, list(backend :: module() | {backend :: module(), backend_config :: term()})},
          {:validations,
           list(
             validation_fun ::
               (Ecto.Changeset.t(), Beacon.MediaLibrary.UploadMetadata.t() -> Ecto.Changeset.t())
               | {validation_fun :: (Ecto.Changeset.t(), Beacon.MediaLibrary.UploadMetadata.t() -> Ecto.Changeset.t()), validation_config :: term()}
           )},
          {:processor, {prossesor_fun :: (Beacon.MediaLibrary.UploadMetadata.t() -> Beacon.MediaLibrary.UploadMetadata.t()), any()}}
        ]

  @typedoc """
  Attach steps into Beacon's internal life-cycle stages to inject custom functionality.
  """
  @type lifecycle :: [lifecycle_stage()]

  @typedoc """
  Life-cycle stages.
  """
  @type lifecycle_stage ::
          {:load_template,
           [
             {format :: String.t(),
              [
                {identifier :: atom(),
                 fun ::
                   (Beacon.Template.t(), Beacon.Template.LoadMetadata.t() ->
                      {:cont, Beacon.Template.t()} | {:halt, Beacon.Template.t()} | {:halt, Exception.t()})}
              ]}
           ]}
          | {:render_template,
             [
               {format :: String.t(),
                [
                  {identifier :: atom(),
                   fun ::
                     (Beacon.Template.t(), Beacon.Template.RenderMetadata.t() ->
                        {:cont, Beacon.Template.t()} | {:halt, Beacon.Template.t()} | {:halt, Exception.t()})}
                ]}
             ]}
          | {:after_create_page, [{identifier :: atom(), fun :: (Content.Page.t() -> {:cont, Content.Page.t()} | {:halt, Exception.t()})}]}
          | {:after_update_page, [{identifier :: atom(), fun :: (Content.Page.t() -> {:cont, Content.Page.t()} | {:halt, Exception.t()})}]}
          | {:after_publish_page, [{identifier :: atom(), fun :: (Content.Page.t() -> {:cont, Content.Page.t()} | {:halt, Exception.t()})}]}
          | {:upload_asset,
             [
               {identifier :: atom(), fun :: (Ecto.Schema.t(), Beacon.MediaLibrary.UploadMetadata.t() -> {:cont, any()} | {:halt, Exception.t()})}
             ]}

  @typedoc """
  Add extra fields to pages.
  """
  @type extra_page_fields :: [module()]

  @typedoc """
  Default meta tags added to new pages.
  """
  @type default_meta_tags :: [%{binary() => binary()}]

  @type t :: %__MODULE__{
          site: Beacon.Types.Site.t(),
          router: router(),
          data_source: data_source(),
          authorization_source: authorization_source(),
          css_compiler: css_compiler(),
          tailwind_config: tailwind_config(),
          live_socket_path: live_socket_path(),
          safe_code_check: safe_code_check(),
          template_formats: template_formats(),
          assets: assets(),
          allowed_media_types: allowed_media_types(),
          lifecycle: lifecycle(),
          extra_page_fields: extra_page_fields(),
          default_meta_tags: default_meta_tags()
        }

  @default_load_template [
    {:heex,
     [
       safe_code_check: &Beacon.Template.HEEx.safe_code_check/2,
       compile_heex: &Beacon.Template.HEEx.compile/2
     ]},
    {:markdown,
     [
       convert_to_html: &Beacon.Template.Markdown.convert_to_html/2,
       safe_code_check: &Beacon.Template.HEEx.safe_code_check/2,
       compile_heex: &Beacon.Template.HEEx.compile/2
     ]}
  ]

  @default_render_template [
    {:heex,
     [
       eval_heex_ast: &Beacon.Template.HEEx.eval_ast/2
     ]},
    {:markdown,
     [
       eval_heex_ast: &Beacon.Template.HEEx.eval_ast/2
     ]}
  ]

  @default_media_types ["image/jpeg", "image/gif", "image/png", "image/webp"]

  defstruct site: nil,
            router: nil,
            data_source: nil,
            authorization_source: Beacon.Authorization.DefaultPolicy,
            css_compiler: Beacon.TailwindCompiler,
            tailwind_config: Path.join(Application.app_dir(:beacon, "priv"), "tailwind.config.js.eex"),
            live_socket_path: "/live",
            # TODO: change safe_code_check to true when it's ready to parse complex codes
            safe_code_check: false,
            template_formats: [
              {:heex, "HEEx (HTML)"},
              {:markdown, "Markdown (GitHub Flavored version)"}
            ],
            assets: [],
            allowed_media_types: @default_media_types,
            lifecycle: [
              load_template: @default_load_template,
              render_template: @default_render_template,
              after_create_page: [],
              after_update_page: [],
              after_publish_page: []
            ],
            extra_page_fields: [],
            default_meta_tags: []

  @type option ::
          {:site, Beacon.Types.Site.t()}
          | {:router, router()}
          | {:data_source, data_source()}
          | {:authorization_source, authorization_source()}
          | {:css_compiler, css_compiler()}
          | {:tailwind_config, tailwind_config()}
          | {:live_socket_path, live_socket_path()}
          | {:safe_code_check, safe_code_check()}
          | {:template_formats, template_formats()}
          | {:assets, assets()}
          | {:allowed_media_types, allowed_media_types()}
          | {:lifecycle, lifecycle()}
          | {:extra_page_fields, extra_page_fields()}
          | {:default_meta_tags, default_meta_tags()}

  @doc """
  Build a new `%Beacon.Config{}` instance to hold the entire configuration for each site.

  ## Options

    * `:site` - `t:Beacon.Types.Site.t/0` (required)

    * `:router` - `t:router/0` (required)

    * `:data_source` - `t:data_source/0` (optional)

    * `:authorization_source` - `t:authorization_source/0` (optional).
    Note this config can't be `nil`. Defaults to `Beacon.Authorization.DefaultPolicy`.

    * `css_compiler` - `t:css_compiler/0` (optional).
   Defaults to `Beacon.TailwindCompiler`.

    * `:tailwind_config` - `t:tailwind_config/0` (optional).
    Defaults to `Path.join(Application.app_dir(:beacon, "priv"), "tailwind.config.js.eex")`.

    * `:live_socket_path` - `t:live_socket_path/0` (optional).
    Defaults to `"/live"`.

    * `:safe_code_check` - `t:safe_code_check/0` (optional).
    Defaults to `false`.

    * `:template_formats` - `t:template_formats/0` (optional).
    Defaults to:

          [
            {:heex, "HEEx (HTML)"},
            {:markdown, "Markdown (GitHub Flavored version)"}
          ]

    Note that the default config is merged with your config.

    * `lifecycle` - `t:lifecycle/0` (optional).
    Note that the default config is merged with your config.

    * `:extra_page_fields` - `t:extra_page_fields/0` (optional)

    * `:default_meta_tags` - `t:default_meta_tags/0` (optional)

  ## Example

      iex> Beacon.Config.new(
        site: :my_site,
        router: MyApp.Router,
        data_source: MyApp.SiteDataSource,
        authorization_source: MyApp.SiteAuthnPolicy,
        tailwind_config: Path.join(Application.app_dir(:my_app, "priv"), "tailwind.config.js.eex"),
        template_formats: [
          {:custom_format, "My Custom Format"}
        ],
        lifecycle: [
          load_template: [
            {:custom_format,
             [
               validate: fn template, _metadata -> MyEngine.validate(template) end
             ]}
          ],
          render_template: [
            {:custom_format,
             [
               assigns: fn template, %{assigns: assigns} -> MyEngine.parse_to_html(template, assigns) end,
               compile: &Beacon.Template.HEEx.compile/2,
               eval: &Beacon.Template.HEEx.eval_ast/2
             ]}
          ],
          after_publish_page: [
            notify_admin: fn page -> {:cont, MyApp.send_email(page)} end
          ]
        ]
      )
      %Beacon.Config{
        site: :my_site,
        router: MyApp.Router,
        data_source: MyApp.SiteDataSource,
        authorization_source: MyApp.SiteAuthnPolicy,
        css_compiler: Beacon.TailwindCompiler,
        tailwind_config: "/my_app/priv/tailwind.config.js.eex",
        live_socket_path: "/live",
        safe_code_check: false,
        template_formats: [
          heex: "HEEx (HTML)",
          markdown: "Markdown (GitHub Flavored version)",
          custom_format: "My Custom Format"
        ],
        media_types: ["image/jpeg", "image/gif", "image/png", "image/webp"],
        assets:[
          {"image/*", [backends: [Beacon.MediaLibrary.Backend.Repo], validations: [&SomeModule.some_function/2]]},
        ]
        lifecycle: [
          load_template: [
            heex: [
              safe_code_check: &Beacon.Template.HEEx.safe_code_check/2,
              compile_heex: &Beacon.Template.HEEx.compile/2
            ],
            markdown: [
              convert_to_html: &Beacon.Template.Markdown.convert_to_html/2,
              safe_code_check: &Beacon.Template.HEEx.safe_code_check/2,
              compile_heex: &Beacon.Template.HEEx.compile/2
            ],
            custom_format: [
              validate: #Function<41.3316493/2 in :erl_eval.expr/6>
            ]
          ],
          render_template: [
            heex: [
              eval_heex_ast: &Beacon.Template.HEEx.eval_ast/2
            ],
            markdown: [
              eval_heex_ast: &Beacon.Template.HEEx.eval_ast/2
            ],
            custom_format: [
              assigns: #Function<41.3316493/2 in :erl_eval.expr/6>,
              compile: &Beacon.Template.HEEx.compile/2,
              eval: &Beacon.Template.HEEx.eval_ast/2
            ]
          ],
          after_create_page: [],
          after_update_page: [],
          after_publish_page: [
            notify_admin: #Function<42.3316493/1 in :erl_eval.expr/6>
          ],
          upload_asset: [],
        ],
        extra_page_fields: [],
        default_meta_tags: []
      }

  """
  @spec new([option]) :: t()
  def new(opts) do
    # TODO: validate opts

    opts[:site] || raise "missing required option :site"
    opts[:router] || raise "missing required option :router"

    template_formats =
      Keyword.merge(
        [
          {:heex, "HEEx (HTML)"},
          {:markdown, "Markdown (GitHub Flavored version)"}
        ],
        Keyword.get(opts, :template_formats, [])
      )

    lifecycle = [
      load_template: Keyword.merge(@default_load_template, get_in(opts, [:lifecycle, :load_template]) || []),
      render_template: Keyword.merge(@default_render_template, get_in(opts, [:lifecycle, :render_template]) || []),
      after_create_page: get_in(opts, [:lifecycle, :after_create_page]) || [],
      after_update_page: get_in(opts, [:lifecycle, :after_update_page]) || [],
      after_publish_page: get_in(opts, [:lifecycle, :after_publish_page]) || [],
      upload_asset: get_in(opts, [:lifecycle, :upload_asset]) || [thumbnail: &Beacon.Lifecycle.Asset.thumbnail/2]
    ]

    allowed_media_types = Keyword.get(opts, :allowed_media_types, @default_media_types)
    validate_allowed_media_types!(allowed_media_types)

    assigned_assets = Keyword.get(opts, :assets, [])
    assets = process_assets_config(allowed_media_types, assigned_assets)

    default_meta_tags = Keyword.get(opts, :default_meta_tags, [])

    opts =
      opts
      |> Keyword.put(:template_formats, template_formats)
      |> Keyword.put(:lifecycle, lifecycle)
      |> Keyword.put(:allowed_media_types, allowed_media_types)
      |> Keyword.put(:assets, assets)
      |> Keyword.put(:default_meta_tags, default_meta_tags)

    struct!(__MODULE__, opts)
  end

  @doc """
  Returns the `Beacon.Config` for `site`.
  """
  @spec fetch!(Beacon.Types.Site.t()) :: t()
  def fetch!(site) when is_atom(site) do
    Registry.config!(site)
  end

  @spec config_for_media_type(Beacon.Config.t(), String.t()) :: media_type_config()
  def config_for_media_type(beacon_config, media_type) do
    case get_media_type_config(beacon_config.assets, media_type) do
      nil ->
        raise Beacon.LoaderError, """
        Expected to find a `media_type()` configuration for `#{media_type}` in `Beacon.Config.assets`.

        You can key that configuration with `#{media_type}` or a catchall like `#{build_generic_media_type(media_type)}`
        """

      {_, config} ->
        config
    end
  end

  defp get_media_type_config(media_type_configs, media_type) do
    generic_type = build_generic_media_type(media_type)

    Enum.find(media_type_configs, fn {type, _} ->
      type == media_type || type == generic_type
    end)
  end

  defp build_generic_media_type(media_type) do
    [cat, _] = String.split(media_type, "/")
    "#{cat}/*"
  end

  defp validate_allowed_media_types!(allowed_media_types) do
    Enum.each(allowed_media_types, fn media_type ->
      case Plug.Conn.Utils.media_type(media_type) do
        {:ok, _, "*", _} ->
          raise Beacon.LoaderError, """
          Catchall Media Types are not allowed in allowed
          """

        :error ->
          raise_invalid_media_type(media_type)

        _ ->
          media_type
      end
    end)
  end

  defp process_assets_config(allowed_media_types, assigned_assets) do
    Enum.reduce(
      allowed_media_types,
      assigned_assets,
      fn media_type, acc ->
        if :error == Plug.Conn.Utils.media_type(media_type) do
          raise_invalid_media_type(media_type)
        end

        if get_media_type_config(assigned_assets, media_type) do
          acc
        else
          acc ++ [{media_type, [{:backends, [Beacon.MediaLibrary.Backend.Repo]}]}]
        end
      end
    )
    |> Enum.map(fn
      {media_type, config} ->
        config =
          config
          |> Keyword.put_new(:validations, [])
          |> ensure_processor(media_type)

        {media_type, config}
    end)
  end

  defp raise_invalid_media_type(media_type) do
    raise(Beacon.LoaderError, "Unknown Media type: #{media_type}")
  end

  defp ensure_processor(config, media_type) do
    processor =
      case Plug.Conn.Utils.media_type(media_type) do
        {:ok, "image", _, _} -> &Beacon.MediaLibrary.Processors.Image.process!/1
        _ -> &Beacon.MediaLibrary.Processors.Default.process!/1
      end

    Keyword.put_new(config, :processor, processor)
  end
end
