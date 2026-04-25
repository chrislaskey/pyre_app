import Config
import Dotenvy

# Dotenvy environmental variable configuration

env_dir_prefix = System.get_env("RELEASE_ROOT") || Path.expand("./env")

source!([
  Path.absname(".env", env_dir_prefix),
  Path.absname("#{config_env()}.env", env_dir_prefix),
  Path.absname("#{config_env()}.overrides.env", env_dir_prefix),
  System.get_env()
])

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/app start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if env!("PHX_SERVER", :string, nil) == "true" do
  config :app, AppWeb.Endpoint, server: true
end

config :app, AppWeb.Endpoint, http: [port: env!("PORT", :integer, 4000)]

# Pyre lib

if env!("PYRE_GITHUB_REPO_URL", :string, nil) do
  config :pyre, :github,
    repositories: [
      [
        url: env!("PYRE_GITHUB_REPO_URL", :string),
        token: env!("PYRE_GITHUB_TOKEN", :string),
        base_branch: env!("PYRE_GITHUB_BASE_BRANCH", :string, "main")
      ]
      # [
      #   url: System.get_env("PYRE_ADDITIONAL_GITHUB_REPO_URL"),
      #   token: System.get_env("PYRE_ADDITIONAL_GITHUB_TOKEN"),
      #   base_branch: System.get_env("PYRE_ADDITIONAL_GITHUB_BASE_BRANCH", "main")
      # ]
    ]
end

config :pyre, :github_apps, [
  if env!("PYRE_GITHUB_APP_ID", :string, nil) do
    [
      app_id: env!("PYRE_GITHUB_APP_ID", :string),
      private_key: env!("PYRE_GITHUB_APP_PRIVATE_KEY", :string),
      webhook_secret: env!("PYRE_GITHUB_WEBHOOK_SECRET", :string),
      bot_slug: env!("PYRE_GITHUB_APP_BOT_SLUG", :string, nil)
    ]
  end
]

# Pyre client

config :pyre_client,
  server_url: "ws://localhost:#{env!("PORT", :string, "4000")}/websocket",
  connection_id: env!("PYRE_CLIENT_CONNECTION_ID", :string, "local-worker"),
  connection_name: env!("PYRE_CLIENT_CONNECTION_NAME", :string, "local"),
  available_capacity: 1,
  enabled_workflows: []

if paths = env!("PYRE_ALLOWED_PATHS", :string, nil) do
  config :pyre,
    allowed_paths:
      paths
      |> String.split(",", trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.map(&Path.expand/1)
end

config :app, :accounts, [
  if env!("APP_ADMIN_USER_EMAIL", :string, nil) do
    [
      email: env!("APP_ADMIN_USER_EMAIL", :string),
      password: env!("APP_ADMIN_USER_PASSWORD", :string)
    ]
  end
]

if config_env() == :prod do
  database_path =
    env!("DATABASE_PATH", :string, nil) ||
      raise """
      environment variable DATABASE_PATH is missing.
      For example: /etc/app/app.db
      """

  config :app, App.Repo,
    database: database_path,
    pool_size: env!("POOL_SIZE", :integer, 5)

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    env!("SECRET_KEY_BASE", :string, nil) ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = env!("PHX_HOST", :string, "example.com")

  config :app, :dns_cluster_query, env!("DNS_CLUSTER_QUERY", :string, nil)

  config :app, AppWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: env!("PORT", :integer, 4000)
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :app, AppWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :app, AppWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Here is an example configuration for Mailgun:
  #
  #     config :app, App.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # Most non-SMTP adapters require an API client. Swoosh supports Req, Hackney,
  # and Finch out-of-the-box. This configuration is typically done at
  # compile-time in your config/prod.exs:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Req
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
end
