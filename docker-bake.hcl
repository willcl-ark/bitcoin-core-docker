// docker-bake.hcl - Build configuration for Bitcoin Core Docker images
//
// Usage:
//   docker buildx bake releases          # Build all release images
//   docker buildx bake v29.2_all         # Build specific version (debian + alpine)
//   docker buildx bake all_alpine        # Build all alpine variants
//   docker buildx bake --print           # Show build configuration
//
// Variables can be overridden via environment:
//   REGISTRY=myregistry/bitcoin docker buildx bake releases
//   PUSH=true docker buildx bake releases

// ============================================================================
// Variables
// ============================================================================

variable "REGISTRY" {
  default = "docker.io/bitcoin/bitcoin"
}

variable "PUSH" {
  default = false
}

// Set to the latest release version for "latest" tag assignment
variable "LATEST_VERSION" {
  default = "30.1"
}

// ============================================================================
// Platform definitions
// ============================================================================

function "debian_platforms" {
  params = []
  result = ["linux/amd64", "linux/arm64", "linux/arm/v7"]
}

function "alpine_platforms" {
  params = []
  result = ["linux/amd64"]
}

function "master_platforms" {
  params = []
  result = ["linux/amd64", "linux/arm64"]
}

// ============================================================================
// Groups
// ============================================================================

group "default" {
  targets = ["releases"]
}

group "releases" {
  targets = ["v29_2_all", "v28_3_all", "v27_2_all"]
}

group "all" {
  targets = ["releases", "master_all"]
}

group "all_debian" {
  targets = ["v29_2", "v28_3", "v27_2", "master"]
}

group "all_alpine" {
  targets = ["v29_2_alpine", "v28_3_alpine", "v27_2_alpine", "master_alpine"]
}

// Per-version groups
group "v29_2_all" {
  targets = ["v29_2", "v29_2_alpine"]
}

group "v28_3_all" {
  targets = ["v28_3", "v28_3_alpine"]
}

group "v27_2_all" {
  targets = ["v27_2", "v27_2_alpine"]
}

group "master_all" {
  targets = ["master", "master_alpine"]
}

// ============================================================================
// Base target
// ============================================================================

target "_common" {
  output = PUSH ? ["type=registry"] : ["type=docker"]
}

// ============================================================================
// Version 29.2
// ============================================================================

target "v29_2" {
  inherits   = ["_common"]
  context    = "./29.2"
  dockerfile = "Dockerfile"
  platforms  = debian_platforms()
  tags = compact([
    "${REGISTRY}:29.2",
    "${REGISTRY}:29",
    LATEST_VERSION == "29.2" ? "${REGISTRY}:latest" : "",
  ])
}

target "v29_2_alpine" {
  inherits   = ["_common"]
  context    = "./29.2/alpine"
  dockerfile = "Dockerfile"
  platforms  = alpine_platforms()
  tags = compact([
    "${REGISTRY}:29.2-alpine",
    "${REGISTRY}:29-alpine",
    LATEST_VERSION == "29.2" ? "${REGISTRY}:alpine" : "",
  ])
}

// ============================================================================
// Version 28.3
// ============================================================================

target "v28_3" {
  inherits   = ["_common"]
  context    = "./28.3"
  dockerfile = "Dockerfile"
  platforms  = debian_platforms()
  tags = compact([
    "${REGISTRY}:28.3",
    "${REGISTRY}:28",
    LATEST_VERSION == "28.3" ? "${REGISTRY}:latest" : "",
  ])
}

target "v28_3_alpine" {
  inherits   = ["_common"]
  context    = "./28.3/alpine"
  dockerfile = "Dockerfile"
  platforms  = alpine_platforms()
  tags = compact([
    "${REGISTRY}:28.3-alpine",
    "${REGISTRY}:28-alpine",
    LATEST_VERSION == "28.3" ? "${REGISTRY}:alpine" : "",
  ])
}

// ============================================================================
// Version 27.2
// ============================================================================

target "v27_2" {
  inherits   = ["_common"]
  context    = "./27.2"
  dockerfile = "Dockerfile"
  platforms  = debian_platforms()
  tags = compact([
    "${REGISTRY}:27.2",
    "${REGISTRY}:27",
    LATEST_VERSION == "27.2" ? "${REGISTRY}:latest" : "",
  ])
}

target "v27_2_alpine" {
  inherits   = ["_common"]
  context    = "./27.2/alpine"
  dockerfile = "Dockerfile"
  platforms  = alpine_platforms()
  tags = compact([
    "${REGISTRY}:27.2-alpine",
    "${REGISTRY}:27-alpine",
    LATEST_VERSION == "27.2" ? "${REGISTRY}:alpine" : "",
  ])
}

// ============================================================================
// Master (nightly builds)
// ============================================================================

target "master" {
  inherits   = ["_common"]
  context    = "./master"
  dockerfile = "Dockerfile"
  platforms  = master_platforms()
  tags       = ["${REGISTRY}:master"]
  // Disable cache for git clone layer to get latest commits
  no-cache-filter = ["build"]
}

target "master_alpine" {
  inherits   = ["_common"]
  context    = "./master/alpine"
  dockerfile = "Dockerfile"
  platforms  = master_platforms()
  tags       = ["${REGISTRY}:master-alpine"]
  no-cache-filter = ["build"]
}
