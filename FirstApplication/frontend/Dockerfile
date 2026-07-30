FROM dhi.io/python:3.13-debian13-dev AS builder
WORKDIR /app
COPY requirements.txt .
RUN python -m venv /opt/venv
RUN /opt/venv/bin/pip install --no-cache-dir --require-hashes -r requirements.txt

FROM dhi.io/python:3.13-debian13-dev
WORKDIR /app
COPY --from=builder /opt/venv /opt/venv
COPY . .
ENV PATH="/opt/venv/bin:$PATH"
EXPOSE 8501
HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=3 \
  CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8501/_stcore/health', timeout=2)"]
CMD ["python", "-m", "streamlit", "run", "frontend.py", "--server.address=0.0.0.0", "--server.port=8501"]
