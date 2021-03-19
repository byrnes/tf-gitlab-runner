terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "2.11.0"
    }
  }
}

variable "registration_tokens" {
  type = set(string)
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}

# Create a container
resource "docker_container" "runner" {
  for_each = var.registration_tokens
  image    = docker_image.gitlab-runner.latest
  name     = uuid()

  mounts {
    target = "/var/run/docker.sock"
    source = "/var/run/docker.sock"
    type   = "bind"
  }

  provisioner "local-exec" {
    command = "docker exec $ID gitlab-runner register --non-interactive --url https://gitlab.com --registration-token $TOKEN --name $NAME --executor docker --docker-image alpine:latest --docker-privileged --docker-volumes \"/certs/client\""
    environment = {
      ID    = self.id
      TOKEN = each.key
      NAME  = self.name
    }
  }

  provisioner "local-exec" {
    when    = destroy
    command = "docker exec $ID gitlab-runner unregister --all-runners"
    environment = {
      ID = self.id
    }
  }

  provisioner "local-exec" {
    command = "docker exec $ID sed -i 's/concurrent = 1/concurrent = 10/g' /etc/gitlab-runner/config.toml"
    environment = {
      ID = self.id
    }
  }
}


resource "docker_image" "gitlab-runner" {
  name = "gitlab/gitlab-runner:latest"
}
