# Minimal image for workflow-python dogfood Docker + Trivy image integration CI.
FROM python:3.11-slim
RUN useradd --no-create-home --uid 10001 appuser
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt pytest==9.0.3
COPY tests ./tests/
USER appuser
CMD ["python", "-m", "pytest", "-q", "tests/"]
