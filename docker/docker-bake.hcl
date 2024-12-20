variable "DOCKER_REGISTRY" {
  default = ""
}

variable "KAFKA_VERSION" {
  default = "3.9.0"
}

variable "SCALA_VERSION" {
  default = "2.13"
}

group "default" {
  targets = ["jvm"]
}

target "default" {
  attest = [
    "type=provenance,mode=min"
  ]
  contexts = {
    resources = "resources"
  }
  args = {
    kafka_url = "https://archive.apache.org/dist/kafka/${KAFKA_VERSION}/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz"
    build_date = formatdate("D MMMM YYYY", timestamp())
  }
}

target "jvm" {
  inherits   = ["default"]
  context    = "jvm"
  tags       = ["${DOCKER_REGISTRY}${DOCKER_REGISTRY != "" ? "/" : ""}apache/kafka:${KAFKA_VERSION}"]
}


target "native" {
  inherits   = ["default"]
  context    = "native"
  tags       = ["${DOCKER_REGISTRY}${DOCKER_REGISTRY != "" ? "/" : ""}apache/kafka-native:${KAFKA_VERSION}"]
}

