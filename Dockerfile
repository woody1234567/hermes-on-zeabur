FROM nousresearch/hermes-agent:v2026.6.5
LABEL "language"="python"
EXPOSE 8642

CMD ["gateway", "run"]
