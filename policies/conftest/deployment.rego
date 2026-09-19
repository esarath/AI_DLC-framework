package main

# AI-DLC guardrails evaluated against rendered Kustomize output in CI
# (security-scan.yml) and optionally in-cluster via Gatekeeper equivalents.

deny contains msg if {
  input.kind == "Deployment"
  some i
  c := input.spec.template.spec.containers[i]
  not c.resources.requests.cpu
  msg := sprintf("Deployment/%s container %q missing cpu request", [input.metadata.name, c.name])
}

deny contains msg if {
  input.kind == "Deployment"
  some i
  c := input.spec.template.spec.containers[i]
  not c.resources.limits.memory
  msg := sprintf("Deployment/%s container %q missing memory limit", [input.metadata.name, c.name])
}

deny contains msg if {
  input.kind == "Deployment"
  some i
  c := input.spec.template.spec.containers[i]
  not c.securityContext.readOnlyRootFilesystem
  msg := sprintf("Deployment/%s container %q must use readOnlyRootFilesystem", [input.metadata.name, c.name])
}

deny contains msg if {
  input.kind == "Deployment"
  some i
  c := input.spec.template.spec.containers[i]
  endswith(c.image, ":latest")
  msg := sprintf("Deployment/%s container %q uses mutable :latest tag", [input.metadata.name, c.name])
}

deny contains msg if {
  input.kind == "Deployment"
  not input.spec.template.spec.securityContext.runAsNonRoot
  msg := sprintf("Deployment/%s must set pod securityContext.runAsNonRoot", [input.metadata.name])
}

warn contains msg if {
  input.kind == "Deployment"
  input.spec.replicas < 2
  msg := sprintf("Deployment/%s has <2 replicas — no HA during Spot eviction", [input.metadata.name])
}

deny contains msg if {
  input.kind == "Deployment"
  not input.spec.template.spec.tolerations
  msg := sprintf("Deployment/%s must tolerate the Spot node taint", [input.metadata.name])
}
