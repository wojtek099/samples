FROM python:3.7.5-alpine 
LABEL application=watcher

# Install basic utilities
RUN apk add --no-cache bash gcc g++ musl-dev libffi-dev

# Copy requirements
COPY requirements.txt /app/
WORKDIR /app

# Install requirements
RUN pip3 install -r requirements.txt --no-cache-dir --no-input

# Copy scripts
COPY . /app

# Run watcher.py when the container launches
CMD ["python3","-u","watcher.py"]
