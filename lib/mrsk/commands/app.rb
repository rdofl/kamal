require "mrsk/commands/base"

class Mrsk::Commands::App < Mrsk::Commands::Base
  def push
    docker :buildx, :build, "--push", "--platform linux/amd64,linux/arm64", "-t", config.absolute_image, "."
  end

  def pull
    docker :pull, config.absolute_image
  end

  def run(role: :web)
    role = config.role(role)

    docker :run,
      "-d",
      "--restart unless-stopped",
      "--name", config.service_with_version,
      "-e", redact("RAILS_MASTER_KEY=#{config.master_key}"),
      *config.env_args,
      *role.label_args,
      config.absolute_image,
      role.cmd
  end

  def start
    docker :start, config.service_with_version
  end

  def stop
    [ "docker ps -q #{service_filter.join(" ")} | xargs docker stop" ]
  end

  def info
    docker :ps, *service_filter
  end

  def logs
    [ "docker ps -q #{service_filter.join(" ")} | xargs docker logs -n 100 -t" ]
  end

  def exec(*command, interactive: false)
    docker :exec,
      ("-it" if interactive),
      "-e", redact("RAILS_MASTER_KEY=#{config.master_key}"),
      *config.env_args,
      config.service_with_version,
      *command
  end

  def console
    "ssh -t #{config.ssh_user}@#{config.primary_host} '#{exec("bin/rails", "c", interactive: true).join(" ")}'"
  end

  def list_containers
    docker :container, :ls, "-a", *service_filter
  end

  def remove_containers
    docker :container, :prune, "-f", *service_filter
  end

  def remove_images
    docker :image, :prune, "-a", "-f", *service_filter
  end

  def create_new_builder
    docker :buildx, :create, "--use", "--name", config.service
  end

  private
    def service_filter
      [ "--filter", "label=service=#{config.service}" ]
    end
end
