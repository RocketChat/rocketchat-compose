If using external services, the monitoring stack will not be able to scrape metrics from those services.

If you want to scrape metrics from those services, i.e. show the metrics in Grafana deployed by our compose stack, you need to
1. deploy the metrics exporters for those services, unless the services come with their own exporters
2. update the Prometheus scrape configuration to scrape the metrics from the exporters

For \#2, add a new file under `files/prometheus/file_sd_configs.d` instead of updating the existing files under `files/prometheus/file_sd_configs`. This is to avoid conflicts when the stack is updated.

Prometheus should be able to handle scrape failures gracefully for those in-stack exporters.