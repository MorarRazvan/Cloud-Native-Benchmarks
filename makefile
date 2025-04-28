.PHONY: dev dev_wsl dev_wsl_full build_and_push_java destroy

dev:


dev_wsl:
	kind get clusters

dev_wsl_full:
	powershell -ExecutionPolicy Bypass -File ./cluster/setup.ps1

build_and_push_java:
	mvnw clean package
	podman build -t service_template:1.0.0 . 
	podman tag service_template:1.0.0 localhost/service_template:1.0.0
	podman save -o service_template.tar localhost/service_template:1.0.0
	kind load image-archive service_template.tar

destroy:
	kind delete cluster --config=kind-config.yaml