FROM python:3.12-slim
WORKDIR /app
RUN pip install --no-cache-dir flask gunicorn
COPY main.py .
ENV PORT=8080
CMD ["gunicorn", "-w", "2", "-b", "0.0.0.0:8080", "main:app"]