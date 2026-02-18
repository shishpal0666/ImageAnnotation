FROM python:3.9-slim

# Install system dependencies for OpenCV
RUN apt-get update && apt-get install -y libgl1-mesa-glx libglib2.0-0

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
EXPOSE 5000
CMD ["python", "app.py"]
