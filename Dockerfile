FROM nousresearch/hermes-agent:v2026.6.5
LABEL "language"="python"
EXPOSE 8642
EXPOSE 9119
ENTRYPOINT ["/opt/hermes/docker/entrypoint.sh"]
CMD ["gateway", "run"]
